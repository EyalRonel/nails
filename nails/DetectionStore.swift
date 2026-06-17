import Combine
import Foundation

struct DetectionRecord: Codable, Identifiable, Sendable {
    let id: UUID
    let timestamp: Date
    let snapshotFilename: String
    let minTipDistance: Double
    let tipsNearMouth: Int
    let tipsPointingAtMouth: Int
    var isFalseAlarm: Bool?
}

class DetectionStore: ObservableObject {
    @Published var records: [DetectionRecord] = []

    var snapshotsDirectory: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Nails/Snapshots")
    }

    private var storeURL: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Nails/detections.json")
    }

    init() {
        load()
        importOrphanedSnapshots()
    }

    func addRecord(_ record: DetectionRecord) {
        records.append(record)
        save()
    }

    func markAsFalseAlarm(_ id: UUID) {
        guard let idx = records.firstIndex(where: { $0.id == id }) else { return }
        records[idx].isFalseAlarm = true
        save()
        recalculateThreshold()
    }

    func markAsCorrect(_ id: UUID) {
        guard let idx = records.firstIndex(where: { $0.id == id }) else { return }
        records[idx].isFalseAlarm = false
        save()
        recalculateThreshold()
    }

    func clearLabel(_ id: UUID) {
        guard let idx = records.firstIndex(where: { $0.id == id }) else { return }
        records[idx].isFalseAlarm = nil
        save()
        recalculateThreshold()
    }

    func clearAll() {
        let fm = FileManager.default
        try? fm.removeItem(at: snapshotsDirectory)
        try? fm.removeItem(at: storeURL)
        records.removeAll()
        UserDefaults.standard.removeObject(forKey: "adaptiveProximityThreshold")
    }

    func snapshotURL(for record: DetectionRecord) -> URL {
        snapshotsDirectory.appendingPathComponent(record.snapshotFilename)
    }

    var reviewedCount: Int {
        records.filter { $0.isFalseAlarm != nil }.count
    }

    var confirmedCount: Int {
        records.filter { $0.isFalseAlarm == false }.count
    }

    var falseAlarmCount: Int {
        records.filter { $0.isFalseAlarm == true }.count
    }

    private func importOrphanedSnapshots() {
        let fm = FileManager.default
        guard let files = try? fm.contentsOfDirectory(at: snapshotsDirectory, includingPropertiesForKeys: [.creationDateKey]) else { return }

        let knownFilenames = Set(records.map(\.snapshotFilename))
        var added = false

        for file in files where file.pathExtension == "jpg" {
            let filename = file.lastPathComponent
            guard !knownFilenames.contains(filename) else { continue }

            let created = (try? file.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? Date()
            let record = DetectionRecord(
                id: UUID(),
                timestamp: created,
                snapshotFilename: filename,
                minTipDistance: 0,
                tipsNearMouth: 0,
                tipsPointingAtMouth: 0
            )
            records.append(record)
            added = true
        }

        if added { save() }
    }

    private func recalculateThreshold() {
        let truePositives = records.filter { $0.isFalseAlarm == false }
        let falsePositives = records.filter { $0.isFalseAlarm == true }

        guard !truePositives.isEmpty else { return }

        let maxTrueDist = truePositives.map(\.minTipDistance).max()!

        let threshold: Double
        if let minFalseDist = falsePositives.map(\.minTipDistance).min(),
           minFalseDist > maxTrueDist {
            // Place threshold between the two distributions
            threshold = (maxTrueDist + minFalseDist) / 2
        } else {
            // Not enough separation — use slightly above max confirmed distance
            threshold = min(maxTrueDist * 1.2, 0.08)
        }

        UserDefaults.standard.set(threshold, forKey: "adaptiveProximityThreshold")
    }

    private func save() {
        let dir = storeURL.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(records) else { return }
        try? data.write(to: storeURL)
    }

    private func load() {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let data = try? Data(contentsOf: storeURL),
              let loaded = try? decoder.decode([DetectionRecord].self, from: data) else { return }
        records = loaded
    }
}
