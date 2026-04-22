import AppKit
import SwiftGrab

@MainActor
final class SwiftGrabAppDelegate: NSObject, NSApplicationDelegate {
    private var panelManager: MenuBarPanelManager?
    private var globalMonitor: Any?
    private var localMonitor: Any?

    func applicationDidFinishLaunching(_ notification: Notification) {
        print("[SwiftGrabApp] applicationDidFinishLaunching")
        AccessibilityPermission.logTrustCheck(context: "applicationDidFinishLaunching")
        panelManager = MenuBarPanelManager()
        print("[SwiftGrabApp] panelManager created")
        installHotkeyMonitors()
        print("[SwiftGrabApp] hotkey monitors installed")

        print("[SwiftGrabApp] ready")

        // Auto-open panel if permission not yet granted
        if !AccessibilityPermission.isTrusted {
            panelManager?.showPanelOnLaunch()
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false // Stay alive as menu bar app even with no windows
    }

    func applicationWillTerminate(_ notification: Notification) {
        if let globalMonitor { NSEvent.removeMonitor(globalMonitor) }
        if let localMonitor { NSEvent.removeMonitor(localMonitor) }
        panelManager?.cleanup()
        SwiftGrabManager.shared.stop()
    }

    // MARK: - Global hotkey (Cmd+Option+I)

    private func installHotkeyMonitors() {
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard event.modifierFlags.contains([.command, .option]),
                  event.charactersIgnoringModifiers?.lowercased() == "i"
            else { return }
            Task { @MainActor in self?.toggleInspector() }
        }

        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard event.modifierFlags.contains([.command, .option]),
                  event.charactersIgnoringModifiers?.lowercased() == "i"
            else { return event }
            Task { @MainActor in self?.toggleInspector() }
            return nil
        }
    }

    private func toggleInspector() {
        if SwiftGrabManager.shared.currentMode != nil {
            SwiftGrabManager.shared.stop()
        } else {
            guard AccessibilityPermission.isTrusted else {
                panelManager?.showPanel()
                return
            }
            panelManager?.hidePanel()
            SwiftGrabManager.shared.start(mode: .global)
        }
    }
}
