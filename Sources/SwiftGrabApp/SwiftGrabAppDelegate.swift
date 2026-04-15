import AppKit
import SwiftGrab

@MainActor
final class SwiftGrabAppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var globalMonitor: Any?
    private var localMonitor: Any?

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupStatusItem()
        installHotkeyMonitors()

        // Check Accessibility permission on launch
        if !AccessibilityPermission.isTrusted {
            AccessibilityPermission.requestIfNeeded()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        if let globalMonitor { NSEvent.removeMonitor(globalMonitor) }
        if let localMonitor { NSEvent.removeMonitor(localMonitor) }
    }

    // MARK: - Status bar item

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "scope", accessibilityDescription: "SwiftGrab")
        }

        let menu = NSMenu()
        menu.addItem(withTitle: "Toggle Inspector  ⌘⌥I", action: #selector(toggleInspector), keyEquivalent: "")
        menu.addItem(.separator())

        let permItem = NSMenuItem(title: "Accessibility Permission…", action: #selector(checkPermission), keyEquivalent: "")
        menu.addItem(permItem)

        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit SwiftGrab", action: #selector(quit), keyEquivalent: "q")

        statusItem.menu = menu
    }

    // MARK: - Global hotkey (Cmd+Option+I)

    private func installHotkeyMonitors() {
        // Global monitor — fires when other apps are frontmost
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard event.modifierFlags.contains([.command, .option]),
                  event.charactersIgnoringModifiers?.lowercased() == "i"
            else { return }
            Task { @MainActor in
                self?.toggleInspector()
            }
        }

        // Local monitor — fires when our overlay is frontmost
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard event.modifierFlags.contains([.command, .option]),
                  event.charactersIgnoringModifiers?.lowercased() == "i"
            else { return event }
            Task { @MainActor in
                self?.toggleInspector()
            }
            return nil
        }
    }

    // MARK: - Actions

    @objc private func toggleInspector() {
        if SwiftGrabManager.shared.currentMode != nil {
            SwiftGrabManager.shared.stop()
        } else {
            guard AccessibilityPermission.isTrusted else {
                AccessibilityPermission.showPermissionAlert()
                return
            }
            SwiftGrabManager.shared.start(mode: .global)
        }
    }

    @objc private func checkPermission() {
        if AccessibilityPermission.isTrusted {
            let alert = NSAlert()
            alert.messageText = "Permission Granted"
            alert.informativeText = "SwiftGrab has Accessibility access."
            alert.alertStyle = .informational
            alert.runModal()
        } else {
            AccessibilityPermission.showPermissionAlert()
        }
    }

    @objc private func quit() {
        SwiftGrabManager.shared.stop()
        NSApplication.shared.terminate(nil)
    }
}
