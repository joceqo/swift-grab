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
                metadata: buildMetadata(window: nil, view: nil, axInfo: nil, hierarchy: nil)
            )
        }

        let localPoint = window.convertPoint(fromScreen: screenPoint)

        // 1. Standard hitTest
        let hitView = window.contentView?.hitTest(localPoint)
        let hitFrame = selectedRectForView(hitView, in: window) ?? window.frame

        // 2. Manual deep subview walk (bypasses hitTest overrides)
        var deepView = hitView
        var deepFrame = hitFrame
        if let contentView = window.contentView {
            let contentLocal = contentView.convert(localPoint, from: nil)
            let walked = deepestSubview(at: contentLocal, in: contentView)
            if walked !== contentView {
                let walkedFrame = selectedRectForView(walked, in: window) ?? hitFrame
                if walkedFrame.width * walkedFrame.height < deepFrame.width * deepFrame.height {
                    deepView = walked
                    deepFrame = walkedFrame
                }
            }
        }

        // 3. Accessibility hit test (can reach into SwiftUI views)
        let axInfo = accessibilityInspect(in: window, at: screenPoint)
        if let axFrame = axInfo?.frame, !axFrame.isEmpty,
           axFrame.width * axFrame.height < deepFrame.width * deepFrame.height {
            deepFrame = axFrame
        }

        // 4. Build view hierarchy from deepest element to window root
        let hierarchy = buildHierarchy(axElement: axInfo?.rawElement, view: deepView, in: window)

        let metadata = buildMetadata(window: window, view: deepView, axInfo: axInfo, hierarchy: hierarchy)

        return AppLocalInspectionResult(
            screenFrame: deepFrame,
            cursorPoint: screenPoint,
            metadata: metadata
        )
    }

    // MARK: - Deep subview walk

    /// Walk NSView.subviews recursively to find the smallest view containing the point.
    /// Bypasses hitTest overrides that might stop at a container view.
    private static func deepestSubview(at point: CGPoint, in view: NSView) -> NSView {
        for subview in view.subviews.reversed() {
            guard !subview.isHidden, subview.alphaValue > 0 else { continue }
            if subview.frame.contains(point) {
                let childPoint = view.convert(point, to: subview)
                return deepestSubview(at: childPoint, in: subview)
            }
        }
        return view
    }

    // MARK: - Accessibility deep inspection

    private struct AXInfo {
        var frame: CGRect?
        var role: String?
        var title: String?
        var label: String?
        var value: String?
        var viewType: String?
        var rawElement: Any?
    }

    private static func accessibilityInspect(in window: NSWindow, at screenPoint: CGPoint) -> AXInfo? {
        guard let axResult = window.contentView?.accessibilityHitTest(screenPoint) else { return nil }

        var info = AXInfo()
        info.rawElement = axResult

        if let view = axResult as? NSView {
            info.viewType = String(describing: type(of: view))
            info.role = view.accessibilityRole()?.rawValue
            info.title = view.accessibilityTitle()
            info.label = view.accessibilityLabel()
            info.value = view.accessibilityValueDescription()
            info.frame = selectedRectForView(view, in: window)
            return info
        }

        // Non-NSView element (SwiftUI internal accessibility nodes)
        if let element = axResult as? NSAccessibilityElementProtocol {
            let frame = element.accessibilityFrame()
            if !frame.isEmpty {
                info.frame = frame
            }
        }

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

    // MARK: - View hierarchy (stack trace)

    /// Build a hierarchy from the selected element up to the window, like React DevTools.
    /// First element is the selected (deepest), subsequent are ancestors.
    private static func buildHierarchy(axElement: Any?, view: NSView?, in window: NSWindow) -> [String] {
        var hierarchy: [String] = []

        // Walk accessibility parent chain first (can see into SwiftUI)
        if let axElement, !(axElement is NSView) {
            var current: Any? = axElement
            while let el = current, !(el is NSView) {
                hierarchy.append(describeAny(el))
                if let ax = el as? NSAccessibilityElementProtocol {
                    current = ax.accessibilityParent()
                } else {
                    break
                }
            }
            // Reached an NSView — continue with the view chain
            if let reachedView = current as? NSView {
                appendViewChain(from: reachedView, in: window, to: &hierarchy)
            }
        } else if let view {
            // No deeper AX element — walk NSView superview chain
            appendViewChain(from: view, in: window, to: &hierarchy)
        }

        return hierarchy
    }

    private static func appendViewChain(from view: NSView, in window: NSWindow, to hierarchy: inout [String]) {
        var current: NSView? = view
        while let v = current {
            hierarchy.append(describeView(v))
            current = v.superview
        }
        // Add window at the end
        let windowDesc = window.title.isEmpty
            ? "NSWindow"
            : "NSWindow \"\(window.title)\""
        hierarchy.append(windowDesc)
    }

    private static func describeView(_ view: NSView) -> String {
        let typeName = String(describing: type(of: view))
        let label = view.accessibilityLabel() ?? view.accessibilityTitle()
        if let label, !label.isEmpty {
            return "\(typeName) \"\(label)\""
        }
        return typeName
    }

    private static func describeAny(_ element: Any) -> String {
        if let accessible = element as? NSAccessibilityProtocol {
            let role = accessible.accessibilityRole()?.rawValue
            let label = accessible.accessibilityLabel() ?? accessible.accessibilityTitle()
            let typeName: String
            if let role {
                typeName = role.hasPrefix("AX") ? String(role.dropFirst(2)) : role
            } else {
                typeName = String(describing: type(of: element))
            }
            if let label, !label.isEmpty {
                return "\(typeName) \"\(label)\""
            }
            return typeName
        }
        return String(describing: type(of: element))
    }

    // MARK: - View frame

    private static func selectedRectForView(_ view: NSView?, in window: NSWindow) -> CGRect? {
        guard let view else { return nil }
        let localRect = view.convert(view.bounds, to: nil)
        return window.convertToScreen(localRect)
    }

    // MARK: - Metadata

    private static func buildMetadata(
        window: NSWindow?,
        view: NSView?,
        axInfo: AXInfo?,
        hierarchy: [String]?
    ) -> GrabPayload.GrabMetadata {
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
            elementDescription: buildDescription(role: role, viewType: viewType, label: label, title: title),
            viewHierarchy: hierarchy
        )
    }

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
