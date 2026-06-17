import ServiceManagement
import SwiftUI

struct SettingsView: View {
    @ObservedObject var cameraManager: CameraManager

    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    @State private var showClearConfirmation = false

    var body: some View {
        Form {
            Section("Cooldowns") {
                HStack {
                    Text("Notification & Picture")
                    Spacer()
                    Slider(value: $cameraManager.alertCooldown, in: 1...60, step: 1)
                        .frame(width: 160)
                    Text("\(Int(cameraManager.alertCooldown))s")
                        .monospacedDigit()
                        .frame(width: 32, alignment: .trailing)
                }
                HStack {
                    Text("Sound")
                    Spacer()
                    Slider(value: $cameraManager.soundCooldown, in: 1...30, step: 1)
                        .frame(width: 160)
                    Text("\(Int(cameraManager.soundCooldown))s")
                        .monospacedDigit()
                        .frame(width: 32, alignment: .trailing)
                }
            }

            Section("Alerts") {
                Toggle("Take Picture on Detection", isOn: $cameraManager.takePictureOnDetection)

                Toggle("Show Screen Alert", isOn: $cameraManager.showScreenAlert)

                Toggle("Play Sound on Detection", isOn: $cameraManager.playSoundOnDetection)

                if cameraManager.playSoundOnDetection {
                    Picker("Sound", selection: $cameraManager.selectedSound) {
                        ForEach(CameraManager.availableSounds, id: \.self) { sound in
                            Text(sound).tag(sound)
                        }
                    }
                    .onChange(of: cameraManager.selectedSound) { _, newValue in
                        let url = URL(fileURLWithPath: "/System/Library/Sounds/\(newValue).aiff")
                        NSSound(contentsOf: url, byReference: true)?.play()
                    }
                }
            }

            Section("General") {
                Toggle("Launch at Login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, newValue in
                        do {
                            if newValue {
                                try SMAppService.mainApp.register()
                            } else {
                                try SMAppService.mainApp.unregister()
                            }
                        } catch {
                            launchAtLogin = SMAppService.mainApp.status == .enabled
                        }
                    }
                Toggle("Pause When Screen Is Locked", isOn: $cameraManager.pauseWhenLocked)
            }

            Section("Data") {
                HStack {
                    VStack(alignment: .leading) {
                        Text("Detection History")
                        Text("\(cameraManager.detectionStore.records.count) detections")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("Clear All", role: .destructive) {
                        showClearConfirmation = true
                    }
                    .alert("Clear All Data?", isPresented: $showClearConfirmation) {
                        Button("Cancel", role: .cancel) {}
                        Button("Clear All", role: .destructive) {
                            cameraManager.detectionStore.clearAll()
                            cameraManager.detectionCount = 0
                        }
                    } message: {
                        Text("This will delete all detection images and reset learned thresholds. This cannot be undone.")
                    }
                }
            }
        }
        .formStyle(.grouped)
        .padding()
        .frame(width: 420, height: 380)
    }
}
