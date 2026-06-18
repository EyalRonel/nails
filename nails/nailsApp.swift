import AppKit
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    weak var cameraManager: CameraManager?
    private var eventMonitor: Any?

    func applicationDidFinishLaunching(_ notification: Notification) {
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .leftMouseUp) { [weak self] event in
            if event.clickCount == 2,
               event.window?.className == "NSStatusBarWindow" {
                self?.cameraManager?.toggleMonitoring()
            }
            return event
        }
    }
}

@main
struct nailsApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var cameraManager = CameraManager()

    init() {
        NSApplication.shared.setActivationPolicy(.accessory)
    }

    var body: some Scene {
        MenuBarExtra {
            ContentView(cameraManager: cameraManager)
                .onAppear {
                    appDelegate.cameraManager = cameraManager
                    if !UserDefaults.standard.bool(forKey: "onboardingComplete") {
                        DispatchQueue.main.async {
                            NSApp.activate(ignoringOtherApps: true)
                            self.openWindow(id: "onboarding")
                        }
                    }
                }
        } label: {
            Image(systemName: menuBarIcon)
        }
        .menuBarExtraStyle(.window)

        Window("Welcome to Nails", id: "onboarding") {
            OnboardingView(cameraManager: cameraManager)
        }
        .windowResizability(.contentSize)
        .windowStyle(.hiddenTitleBar)

        Window("Settings", id: "settings") {
            SettingsView(cameraManager: cameraManager)
        }
        .windowResizability(.contentSize)

        Window("Review Detections", id: "review") {
            SnapshotReviewView(store: cameraManager.detectionStore)
        }
    }

    @Environment(\.openWindow) private var openWindow

    private var menuBarIcon: String {
        if cameraManager.isDetecting {
            return "exclamationmark.triangle.fill"
        }
        if cameraManager.isMonitoring {
            return "eye.fill"
        }
        return "eye.slash"
    }
}
