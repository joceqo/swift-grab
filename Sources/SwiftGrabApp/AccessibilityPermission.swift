import AppKit
import ApplicationServices

enum AccessibilityPermission {
    private static let logPrefix = "[SwiftGrabApp][Accessibility]"

    struct DebugSnapshot {
        let trusted: Bool
        let bundleID: String
        let appName: String
        let bundlePath: String
        let executablePath: String
        let pid: Int32
    }

    static var isTrusted: Bool {
        AXIsProcessTrusted()
    }

    static func logTrustCheck(context: String) {
        let snapshot = debugSnapshot()

        print("\(logPrefix) context=\(context)")
        print("\(logPrefix) trusted=\(snapshot.trusted) pid=\(snapshot.pid)")
        print("\(logPrefix) bundleID=\(snapshot.bundleID) appName=\(snapshot.appName)")
        print("\(logPrefix) bundlePath=\(snapshot.bundlePath)")
        print("\(logPrefix) executablePath=\(snapshot.executablePath)")
    }

    static func debugSnapshot() -> DebugSnapshot {
        DebugSnapshot(
            trusted: isTrusted,
            bundleID: Bundle.main.bundleIdentifier ?? "<nil>",
            appName: Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String ?? "<nil>",
            bundlePath: Bundle.main.bundleURL.path,
            executablePath: Bundle.main.executableURL?.path ?? "<nil>",
            pid: ProcessInfo.processInfo.processIdentifier
        )
    }

    /// Prompt the user for Accessibility permission if not already granted.
    /// macOS shows the system dialog; the app must be restarted after granting.
    static func requestIfNeeded() {
        logTrustCheck(context: "requestIfNeeded-before")
        guard !isTrusted else { return }
        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        let promptedResult = AXIsProcessTrustedWithOptions(options)
        print("\(logPrefix) AXIsProcessTrustedWithOptions returned=\(promptedResult)")
        logTrustCheck(context: "requestIfNeeded-after")
    }

    /// Show an alert explaining why the permission is needed.
    @MainActor
    static func showPermissionAlert() {
        let alert = NSAlert()
        alert.messageText = "Accessibility Permission Required"
        alert.informativeText = "SwiftGrab needs Accessibility access to inspect elements in other apps.\n\nGrant access in System Settings > Privacy & Security > Accessibility, then relaunch."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Open System Settings")
        alert.addButton(withTitle: "Later")

        if alert.runModal() == .alertFirstButtonReturn {
            NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
        }
    }
}
