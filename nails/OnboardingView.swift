import AVFoundation
import SwiftUI

struct OnboardingView: View {
    @ObservedObject var cameraManager: CameraManager
    @Environment(\.dismiss) private var dismiss
    @State private var step = 0

    var body: some View {
        VStack(spacing: 0) {
            if step == 0 {
                welcomeStep
            } else {
                cameraStep
            }
        }
        .frame(width: 420, height: 340)
    }

    private var welcomeStep: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "hand.raised.fingers.spread")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("Welcome to Nails")
                .font(.title.bold())
            Text("Nails watches for nail biting using your webcam and nudges you to stop.\nAll processing happens on-device — nothing leaves your Mac.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 32)
            Spacer()
            Button("Get Started") { step = 1 }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            Spacer().frame(height: 24)
        }
        .padding()
    }

    private var cameraStep: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: cameraIcon)
                .font(.system(size: 48))
                .foregroundStyle(cameraColor)
            Text("Camera Access")
                .font(.title.bold())
            Text(cameraDescription)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 32)
            Spacer()
            cameraButton
            Spacer().frame(height: 24)
        }
        .padding()
    }

    private var cameraIcon: String {
        switch cameraManager.cameraPermission {
        case .authorized: "checkmark.circle.fill"
        case .denied: "xmark.circle.fill"
        case .notDetermined: "camera.fill"
        }
    }

    private var cameraColor: Color {
        switch cameraManager.cameraPermission {
        case .authorized: .green
        case .denied: .red
        case .notDetermined: .secondary
        }
    }

    private var cameraDescription: String {
        switch cameraManager.cameraPermission {
        case .notDetermined:
            "Nails needs camera access to detect nail biting. Your camera feed is processed locally and never recorded or transmitted."
        case .authorized:
            "Camera access granted. You're all set!"
        case .denied:
            "Camera access was denied. Open System Settings to grant access, then come back here."
        }
    }

    @ViewBuilder
    private var cameraButton: some View {
        switch cameraManager.cameraPermission {
        case .notDetermined:
            Button("Allow Camera Access") {
                cameraManager.requestCameraAccess()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        case .authorized:
            Button("Start Monitoring") {
                UserDefaults.standard.set(true, forKey: "onboardingComplete")
                cameraManager.startMonitoring()
                dismiss()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        case .denied:
            VStack(spacing: 12) {
                Button("Open System Settings") {
                    NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Camera")!)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                Button("Check Again") {
                    cameraManager.updateCameraPermission()
                }
                .buttonStyle(.bordered)
                .controlSize(.regular)
            }
        }
    }
}
