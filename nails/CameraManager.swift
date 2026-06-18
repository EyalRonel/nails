import AppKit
import AVFoundation
import Combine
import CoreImage
import CoreMedia
import SwiftUI
import UserNotifications
import Vision

class CameraManager: NSObject, ObservableObject {
    @Published var isMonitoring = false
    @Published var isDetecting = false
    @Published var detectionCount = 0
    @Published var lastSnapshotURL: URL?

    @Published var takePictureOnDetection: Bool = true {
        didSet { UserDefaults.standard.set(takePictureOnDetection, forKey: "takePictureOnDetection") }
    }
    @Published var playSoundOnDetection: Bool = true {
        didSet { UserDefaults.standard.set(playSoundOnDetection, forKey: "playSoundOnDetection") }
    }
    @Published var selectedSound: String = "Funk" {
        didSet { UserDefaults.standard.set(selectedSound, forKey: "selectedSound") }
    }

    static let availableSounds = [
        "Basso", "Blow", "Bottle", "Frog", "Funk", "Glass",
        "Hero", "Morse", "Ping", "Pop", "Purr", "Sosumi", "Submarine", "Tink",
    ]

    private var captureSession: AVCaptureSession?
    let detectionStore = DetectionStore()

    private let processingQueue = DispatchQueue(label: "com.nails.processing", qos: .userInitiated)
    private let ciContext = CIContext()

    @Published var alertCooldown: Double = 10.0 {
        didSet { UserDefaults.standard.set(alertCooldown, forKey: "alertCooldown") }
    }
    @Published var soundCooldown: Double = 3.0 {
        didSet { UserDefaults.standard.set(soundCooldown, forKey: "soundCooldown") }
    }
    @Published var pauseWhenLocked: Bool = true {
        didSet { UserDefaults.standard.set(pauseWhenLocked, forKey: "pauseWhenLocked") }
    }
    @Published var showScreenAlert: Bool = true {
        didSet { UserDefaults.standard.set(showScreenAlert, forKey: "showScreenAlert") }
    }

    nonisolated(unsafe) private var lastAlertTime: Date = .distantPast
    nonisolated(unsafe) private var lastSoundTime: Date = .distantPast
    nonisolated(unsafe) private var consecutiveDetections = 0
    nonisolated(unsafe) private var lastProcessedTime: Date = .distantPast
    private var wasMonitoringBeforeLock = false
    private let detectionThreshold = 3
    private let defaultProximityThreshold = 0.08
    private let processInterval: TimeInterval = 0.2

    override init() {
        let defaults = UserDefaults.standard
        defaults.register(defaults: [
            "takePictureOnDetection": true,
            "playSoundOnDetection": true,
            "selectedSound": "Funk",
            "alertCooldown": 10.0,
            "soundCooldown": 3.0,
            "pauseWhenLocked": true,
            "showScreenAlert": true,
        ])
        super.init()

        takePictureOnDetection = defaults.bool(forKey: "takePictureOnDetection")
        playSoundOnDetection = defaults.bool(forKey: "playSoundOnDetection")
        selectedSound = defaults.string(forKey: "selectedSound") ?? "Funk"
        alertCooldown = defaults.double(forKey: "alertCooldown")
        soundCooldown = defaults.double(forKey: "soundCooldown")
        pauseWhenLocked = defaults.bool(forKey: "pauseWhenLocked")
        showScreenAlert = defaults.bool(forKey: "showScreenAlert")

        let dnc = DistributedNotificationCenter.default()
        dnc.addObserver(self, selector: #selector(screenDidLock), name: .init("com.apple.screenIsLocked"), object: nil)
        dnc.addObserver(self, selector: #selector(screenDidUnlock), name: .init("com.apple.screenIsUnlocked"), object: nil)

        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
        startMonitoring()
    }

    func toggleMonitoring() {
        if isMonitoring {
            stopMonitoring()
        } else {
            startMonitoring()
        }
    }

    func startMonitoring() {
        guard !isMonitoring else { return }

        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            setupAndStart()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                if granted {
                    Task { @MainActor in
                        self.setupAndStart()
                    }
                }
            }
        default:
            break
        }
    }

    func stopMonitoring() {
        let session = captureSession
        processingQueue.async {
            session?.stopRunning()
        }
        isMonitoring = false
        isDetecting = false
        consecutiveDetections = 0
    }

    @objc private func screenDidLock() {
        guard pauseWhenLocked else { return }
        wasMonitoringBeforeLock = isMonitoring
        if isMonitoring {
            stopMonitoring()
        }
    }

    @objc private func screenDidUnlock() {
        guard pauseWhenLocked, wasMonitoringBeforeLock else { return }
        wasMonitoringBeforeLock = false
        startMonitoring()
    }

    private func setupAndStart() {
        let session = AVCaptureSession()
        session.sessionPreset = .medium

        guard let camera = AVCaptureDevice.default(for: .video) else { return }

        do {
            let input = try AVCaptureDeviceInput(device: camera)
            guard session.canAddInput(input) else { return }
            session.addInput(input)

            try camera.lockForConfiguration()
            camera.activeVideoMinFrameDuration = CMTime(value: 1, timescale: 15)
            camera.unlockForConfiguration()
        } catch {
            return
        }

        let output = AVCaptureVideoDataOutput()
        output.alwaysDiscardsLateVideoFrames = true
        output.setSampleBufferDelegate(self, queue: processingQueue)

        guard session.canAddOutput(output) else { return }
        session.addOutput(output)

        captureSession = session
        isMonitoring = true

        processingQueue.async {
            session.startRunning()
        }
    }

    nonisolated var snapshotsDirectory: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Nails/Snapshots")
    }

    nonisolated private func saveDetection(
        from pixelBuffer: CVPixelBuffer,
        minTipDistance: Double,
        tipsNearMouth: Int,
        tipsPointingAtMouth: Int
    ) {
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)

        let dir = snapshotsDirectory
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let filename = "bite_\(formatter.string(from: Date())).jpg"
        let fileURL = dir.appendingPathComponent(filename)

        if let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) {
            try? ciContext.writeJPEGRepresentation(of: ciImage, to: fileURL, colorSpace: colorSpace)
        }

        let record = DetectionRecord(
            id: UUID(),
            timestamp: Date(),
            snapshotFilename: filename,
            minTipDistance: minTipDistance,
            tipsNearMouth: tipsNearMouth,
            tipsPointingAtMouth: tipsPointingAtMouth
        )

        Task { @MainActor in
            self.detectionStore.addRecord(record)
            self.lastSnapshotURL = fileURL
        }
    }

    private func playDetectionSound(_ soundName: String) {
        let soundURL = URL(fileURLWithPath: "/System/Library/Sounds/\(soundName).aiff")
        if let sound = NSSound(contentsOf: soundURL, byReference: true) {
            sound.play()
        } else {
            NSSound.beep()
        }
    }

    private func showScreenAlertOverlay() {
        guard let screen = NSScreen.main else { return }
        let panelWidth: CGFloat = 260
        let panelHeight: CGFloat = 260

        let x = screen.frame.midX - panelWidth / 2
        let y = screen.frame.midY - panelHeight / 2
        let frame = NSRect(x: x, y: y, width: panelWidth, height: panelHeight)

        let panel = NSPanel(
            contentRect: frame,
            styleMask: [.nonactivatingPanel, .borderless],
            backing: .buffered,
            defer: false
        )
        panel.level = .screenSaver
        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.alphaValue = 0

        let hostingView = NSHostingView(rootView: ScreenAlertView())
        hostingView.frame = NSRect(x: 0, y: 0, width: panelWidth, height: panelHeight)
        panel.contentView = hostingView

        panel.orderFrontRegardless()

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.2
            panel.animator().alphaValue = 1
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.5
                panel.animator().alphaValue = 0
            } completionHandler: {
                panel.close()
            }
        }
    }

    private func sendNotification() {
        let content = UNMutableNotificationContent()
        content.title = "Stop Biting!"
        content.body = "Nail biting detected. Take a deep breath."
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
        detectionCount += 1
    }
}

extension CameraManager: AVCaptureVideoDataOutputSampleBufferDelegate {
    nonisolated func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        // Skip frames to reduce CPU — process at ~5fps
        let now = Date()
        guard now.timeIntervalSince(lastProcessedTime) >= processInterval else { return }
        lastProcessedTime = now

        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        let handPoseRequest = VNDetectHumanHandPoseRequest()
        handPoseRequest.maximumHandCount = 2
        let faceLandmarksRequest = VNDetectFaceLandmarksRequest()

        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:])

        do {
            try handler.perform([handPoseRequest, faceLandmarksRequest])
        } catch {
            return
        }

        let hands = handPoseRequest.results ?? []
        let faces = faceLandmarksRequest.results ?? []

        guard !hands.isEmpty,
              let face = faces.first,
              let landmarks = face.landmarks,
              let outerLips = landmarks.outerLips else {
            consecutiveDetections = 0
            Task { @MainActor in self.isDetecting = false }
            return
        }

        // Convert mouth center from face-normalized to image-normalized coordinates
        let bbox = face.boundingBox
        let pointCount = outerLips.pointCount
        let points = outerLips.normalizedPoints

        var mx: CGFloat = 0, my: CGFloat = 0
        for i in 0..<pointCount {
            let p = points[i]
            mx += bbox.origin.x + p.x * bbox.width
            my += bbox.origin.y + p.y * bbox.height
        }
        mx /= CGFloat(pointCount)
        my /= CGFloat(pointCount)

        let mouthPos = CGPoint(x: mx, y: my)
        let proximityThreshold = UserDefaults.standard.object(forKey: "adaptiveProximityThreshold") as? Double
            ?? defaultProximityThreshold

        let fingerJoints: [(tip: VNHumanHandPoseObservation.JointName, dip: VNHumanHandPoseObservation.JointName)] = [
            (.thumbTip, .thumbIP),
            (.indexTip, .indexDIP),
            (.middleTip, .middleDIP),
            (.ringTip, .ringDIP),
            (.littleTip, .littleDIP),
        ]

        var detected = false
        var bestMinDist = Double.infinity
        var bestTipsNear = 0
        var bestTipsPointing = 0

        for hand in hands {
            var tipsNearMouth = 0
            var tipsPointingAtMouth = 0
            var handMinDist = Double.infinity

            for (tip, dip) in fingerJoints {
                guard let tipPoint = try? hand.recognizedPoint(tip),
                      let dipPoint = try? hand.recognizedPoint(dip),
                      tipPoint.confidence > 0.3,
                      dipPoint.confidence > 0.3 else { continue }

                let tipDist = hypot(tipPoint.location.x - mouthPos.x, tipPoint.location.y - mouthPos.y)
                let dipDist = hypot(dipPoint.location.x - mouthPos.x, dipPoint.location.y - mouthPos.y)

                if tipDist < proximityThreshold {
                    tipsNearMouth += 1
                    handMinDist = min(handMinDist, tipDist)
                    if tipDist < dipDist * 0.85 {
                        tipsPointingAtMouth += 1
                    }
                }
            }

            if tipsNearMouth >= 1 && tipsNearMouth <= 3 && tipsPointingAtMouth >= 1 {
                detected = true
                bestMinDist = handMinDist
                bestTipsNear = tipsNearMouth
                bestTipsPointing = tipsPointingAtMouth
                break
            }
        }

        if detected {
            consecutiveDetections += 1

            if consecutiveDetections >= detectionThreshold {
                Task { @MainActor in self.isDetecting = true }
                let now = Date()
                let defaults = UserDefaults.standard

                // Sound plays on its own short cooldown for immediate feedback
                let sCooldown = defaults.double(forKey: "soundCooldown")
                if defaults.bool(forKey: "playSoundOnDetection"),
                   now.timeIntervalSince(lastSoundTime) > sCooldown {
                    lastSoundTime = now
                    let soundName = defaults.string(forKey: "selectedSound") ?? "Funk"
                    Task { @MainActor in self.playDetectionSound(soundName) }
                }

                // Notification + picture use the longer user-configured cooldown
                let cooldown = defaults.double(forKey: "alertCooldown")
                if now.timeIntervalSince(lastAlertTime) > cooldown {
                    lastAlertTime = now

                    if defaults.bool(forKey: "takePictureOnDetection") {
                        saveDetection(
                            from: pixelBuffer,
                            minTipDistance: bestMinDist,
                            tipsNearMouth: bestTipsNear,
                            tipsPointingAtMouth: bestTipsPointing
                        )
                    }
                    Task { @MainActor in
                        self.sendNotification()
                        if self.showScreenAlert {
                            self.showScreenAlertOverlay()
                        }
                    }
                }
            }
        } else {
            consecutiveDetections = 0
            Task { @MainActor in self.isDetecting = false }
        }
    }
}

private struct ScreenAlertView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "hand.raised.fill")
                .font(.system(size: 56))
                .foregroundStyle(.red)

            Text("Stop Biting!")
                .font(.system(size: 22, weight: .semibold))

            Text("Take a deep breath.")
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
        }
        .frame(width: 260, height: 260)
        .background(.ultraThickMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}
