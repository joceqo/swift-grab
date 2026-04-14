import AppKit
import CoreGraphics

struct AppLocalInspectionResult {
    var screenFrame: CGRect
    var cursorPoint: CGPoint
    var metadata: GrabPayload.GrabMetadata
}

@MainActor
enum AppLocalInspector {
    static func inspect(at screenPoint: CGPoint) -> AppLocalInspectionResult {
        let candidateWindows = NSApp.windows
            .filter { $0.isVisible && !$0.isMiniaturized }
            .filter { !$0.isKind(of: NSPanel.self) }

        guard let window = candidateWindows.last(where: { $0.frame.contains(screenPoint) }) else {
            return AppLocalInspectionResult(
                screenFrame: CGRect(origin: screenPoint, size: CGSize(width: 1, height: 1)),
                cursorPoint: screenPoint,
                metadata: buildMetadata(window: nil, view: nil, axInfo: nil)
            )
        }

        let localPoint = window.convertPoint(fromScreen: screenPoint)
        let hitView = window.contentView?.hitTest(localPoint)
        let viewFrame = selectedRectForView(hitView, in: window) ?? window.frame

        // Try accessibility hit test for deeper element inspection.
        // This works same-process without the system Accessibility permission.
        let axInfo = accessibilityInspect(in: window, at: screenPoint)

        // Use the AX frame if it's tighter (smaller area) than the view frame.
        let bestFrame: CGRect
        if let axFrame = axInfo?.frame, !axFrame.isEmpty,
           axFrame.width * axFrame.height < viewFrame.width * viewFrame.height {
            bestFrame = axFrame
        } else {
            bestFrame = viewFrame
        }

        return AppLocalInspectionResult(
            screenFrame: bestFrame,
            cursorPoint: screenPoint,
            metadata: buildMetadata(window: window, view: hitView, axInfo: axInfo)
        )
    }

    // MARK: - Accessibility deep inspection

    private struct AXInfo {
        var frame: CGRect?
        var role: String?
        var title: String?
        var label: String?
        var value: String?
        var viewType: String?
    }

    private static func accessibilityInspect(in window: NSWindow, at screenPoint: CGPoint) -> AXInfo? {
        guard let axResult = window.contentView?.accessibilityHitTest(screenPoint) else { return nil }

        var info = AXInfo()

        // If the AX hit test returned a deeper NSView, extract from it directly.
        if let view = axResult as? NSView {
            info.viewType = String(describing: type(of: view))
            info.role = view.accessibilityRole()?.rawValue
            info.title = view.accessibilityTitle()
            info.label = view.accessibilityLabel()
            info.value = view.accessibilityValueDescription()
            info.frame = selectedRectForView(view, in: window)
            return info
        }

        // Non-NSView element (e.g., SwiftUI internal accessibility nodes).
        // Extract frame from NSAccessibilityElementProtocol.
        if let element = axResult as? NSAccessibilityElementProtocol {
            let frame = element.accessibilityFrame()
            if !frame.isEmpty {
                info.frame = frame
            }
        }

        // Extract role/title/label via NSAccessibilityProtocol.
        if let accessible = axResult as? NSAccessibilityProtocol {
            info.role = accessible.accessibilityRole()?.rawValue
            info.title = accessible.accessibilityTitle()
            info.label = accessible.accessibilityLabel()
            if let val = accessible.accessibilityValue() {
                info.value = String(describing: val)
            }
        }

        return info
    }

    // MARK: - View frame

    private static func selectedRectForView(_ view: NSView?, in window: NSWindow) -> CGRect? {
        guard let view else { return nil }
        let localRect = view.convert(view.bounds, to: nil)
        return window.convertToScreen(localRect)
    }

    // MARK: - Metadata

    private static func buildMetadata(window: NSWindow?, view: NSView?, axInfo: AXInfo?) -> GrabPayload.GrabMetadata {
        let viewType = axInfo?.viewType ?? view.map { String(describing: type(of: $0)) }
        let role = axInfo?.role ?? view?.accessibilityRole()?.rawValue
        let title = axInfo?.title ?? view?.accessibilityTitle()
        let label = axInfo?.label ?? view?.accessibilityLabel()
        let value = axInfo?.value ?? view?.accessibilityValueDescription()

        return GrabPayload.GrabMetadata(
            appBundleIdentifier: Bundle.main.bundleIdentifier,
            processIdentifier: ProcessInfo.processInfo.processIdentifier,
            windowTitle: window?.title,
            viewType: viewType,
            accessibilityRole: role,
            accessibilityTitle: title,
            accessibilityValue: value,
            elementDescription: buildDescription(role: role, viewType: viewType, label: label, title: title)
        )
    }

    /// Build a human-readable one-liner: `Button "Save"`, `StaticText "Hello"`, `NSButton`.
    private static func buildDescription(role: String?, viewType: String?, label: String?, title: String?) -> String {
        let typeName: String
        if let role {
            typeName = role.hasPrefix("AX") ? String(role.dropFirst(2)) : role
        } else if let viewType {
            typeName = viewType
        } else {
            return "Unknown"
        }

        let displayName = label ?? title
        if let displayName, !displayName.isEmpty {
            return "\(typeName) \"\(displayName)\""
        }
        return typeName
    }
}

private extension NSView {
    func accessibilityValueDescription() -> String? {
        if let stringValue = accessibilityValue() as? String {
            return stringValue
        }
        if let numberValue = accessibilityValue() as? NSNumber {
            return numberValue.stringValue
        }
        return nil
    }
}
