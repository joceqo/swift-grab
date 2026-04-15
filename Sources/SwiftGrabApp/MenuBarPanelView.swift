import SwiftUI
import SwiftGrab

struct MenuBarPanelView: View {
    @State private var isTrusted = AccessibilityPermission.isTrusted
    @State private var isInspecting = SwiftGrabManager.shared.currentMode != nil

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Image(systemName: "scope")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.accentColor)
                Text("SwiftGrab")
                    .font(.system(size: 14, weight: .semibold))
                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.top, 12)
            .padding(.bottom, 10)

            Divider().padding(.horizontal, 8)

            // Permission status
            if !isTrusted {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                            .font(.system(size: 12))
                        Text("Accessibility Required")
                            .font(.system(size: 12, weight: .medium))
                    }
                    Text("Grant access to inspect elements in other apps.")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    Button(action: openAccessibilitySettings) {
                        Text("Open System Settings")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                            .background(Color.accentColor)
                            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    }
                    .buttonStyle(.plain)

                    Button("Check Again") {
                        isTrusted = AccessibilityPermission.isTrusted
                    }
                    .font(.system(size: 11))
                    .frame(maxWidth: .infinity)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
            } else {
                // Ready / active state
                HStack(spacing: 6) {
                    Circle()
                        .fill(isInspecting ? .blue : .green)
                        .frame(width: 7, height: 7)
                    Text(isInspecting ? "Inspecting..." : "Ready")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
            }

            Divider().padding(.horizontal, 8)

            // Actions
            VStack(spacing: 2) {
                panelButton(
                    title: isInspecting ? "Stop Inspector" : "Start Inspector",
                    shortcut: "⌘⌥I",
                    action: toggleInspector
                )
                panelButton(title: "Quit", shortcut: "⌘Q", action: quit)
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 6)
        }
        .frame(width: 260)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .shadow(color: .black.opacity(0.14), radius: 12, y: 4)
        .shadow(color: .black.opacity(0.04), radius: 1, y: 1)
    }

    // MARK: - Helpers

    private func panelButton(title: String, shortcut: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Text(title)
                    .font(.system(size: 12))
                Spacer()
                Text(shortcut)
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
    }

    private func toggleInspector() {
        if SwiftGrabManager.shared.currentMode != nil {
            SwiftGrabManager.shared.stop()
            isInspecting = false
        } else {
            guard isTrusted else { return }
            SwiftGrabManager.shared.start(mode: .global)
            isInspecting = true
        }
    }

    private func openAccessibilitySettings() {
        AccessibilityPermission.requestIfNeeded()
    }

    private func quit() {
        SwiftGrabManager.shared.stop()
        NSApp.terminate(nil)
    }
}
