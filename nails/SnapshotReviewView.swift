import AppKit
import SwiftUI

struct SnapshotReviewView: View {
    @ObservedObject var store: DetectionStore

    private let columns = [GridItem(.adaptive(minimum: 180), spacing: 16)]

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("\(store.records.count) detections")
                    .font(.headline)
                Spacer()
                if store.reviewedCount > 0 {
                    Text("\(store.confirmedCount) confirmed")
                        .foregroundStyle(.green)
                    Text("·")
                    Text("\(store.falseAlarmCount) false alarms")
                        .foregroundStyle(.red)
                }
            }
            .padding()

            Divider()

            if store.records.isEmpty {
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "photo.on.rectangle.angled")
                        .font(.system(size: 40))
                        .foregroundStyle(.tertiary)
                    Text("No Detections Yet")
                        .font(.title3.bold())
                        .foregroundStyle(.secondary)
                    Text("Detections will appear here as they happen.")
                        .font(.subheadline)
                        .foregroundStyle(.tertiary)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 16) {
                        ForEach(store.records.reversed()) { record in
                            DetectionCard(record: record, store: store)
                        }
                    }
                    .padding()
                }
            }
        }
        .frame(minWidth: 620, minHeight: 450)
    }
}

struct DetectionCard: View {
    let record: DetectionRecord
    @ObservedObject var store: DetectionStore

    var body: some View {
        VStack(spacing: 8) {
            let url = store.snapshotURL(for: record)
            if let nsImage = NSImage(contentsOf: url) {
                Image(nsImage: nsImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(height: 120)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            } else {
                RoundedRectangle(cornerRadius: 6)
                    .fill(.quaternary)
                    .frame(height: 120)
                    .overlay {
                        Image(systemName: "photo")
                            .foregroundStyle(.tertiary)
                    }
            }

            Text(record.timestamp, format: .dateTime.month(.abbreviated).day().hour().minute())
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack(spacing: 12) {
                Button {
                    store.markAsCorrect(record.id)
                } label: {
                    Image(systemName: record.isFalseAlarm == false ? "checkmark.circle.fill" : "checkmark.circle")
                }
                .buttonStyle(.borderless)
                .foregroundStyle(record.isFalseAlarm == false ? .green : .secondary)
                .help("Mark as correct detection")

                Button {
                    store.markAsFalseAlarm(record.id)
                } label: {
                    Image(systemName: record.isFalseAlarm == true ? "xmark.circle.fill" : "xmark.circle")
                }
                .buttonStyle(.borderless)
                .foregroundStyle(record.isFalseAlarm == true ? .red : .secondary)
                .help("Mark as false alarm")
            }
            .font(.title3)
        }
        .padding(10)
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 10))
        .opacity(record.isFalseAlarm == true ? 0.6 : 1.0)
    }
}
