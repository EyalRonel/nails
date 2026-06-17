import SwiftUI

struct ContentView: View {
    @ObservedObject var cameraManager: CameraManager
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Circle()
                    .fill(statusColor)
                    .frame(width: 8, height: 8)
                Text(statusText)
                    .font(.headline)
                Spacer()
                Toggle("", isOn: monitoringBinding)
                    .toggleStyle(.switch)
                    .labelsHidden()
                    .controlSize(.small)
            }
            .padding(.bottom, 4)

            Divider()

            HStack {
                Image(systemName: "hand.raised.fingers.spread")
                Text("Detections: \(cameraManager.detectionCount)")
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .padding(.vertical, 4)

            Divider()

            MenuItemButton(title: "Settings", icon: "gear", shortcut: "⌘,") {
                openWindow(id: "settings")
                NSApp.activate(ignoringOtherApps: true)
            }

            MenuItemButton(title: "Review Detections", icon: "photo.stack") {
                openWindow(id: "review")
                NSApp.activate(ignoringOtherApps: true)
            }

            Divider()

            MenuItemButton(title: "Quit Nails", icon: "xmark.circle", shortcut: "⌘Q") {
                NSApplication.shared.terminate(nil)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(width: 240)
    }

    private var monitoringBinding: Binding<Bool> {
        Binding(
            get: { cameraManager.isMonitoring },
            set: { _ in cameraManager.toggleMonitoring() }
        )
    }

    private var statusColor: Color {
        if cameraManager.isDetecting { return .red }
        if cameraManager.isMonitoring { return .green }
        return .gray
    }

    private var statusText: String {
        if cameraManager.isDetecting { return "Nail Biting Detected!" }
        if cameraManager.isMonitoring { return "Monitoring" }
        return "Paused"
    }
}

struct MenuItemButton: View {
    let title: String
    let icon: String
    var shortcut: String? = nil
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .frame(width: 16)
                Text(title)
                Spacer()
                if let shortcut {
                    Text(shortcut)
                        .font(.subheadline)
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(isHovered ? Color.accentColor : Color.clear)
            )
            .foregroundStyle(isHovered ? .white : .primary)
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}
