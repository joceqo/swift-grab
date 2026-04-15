import AppKit
import ApplicationServices
import CoreGraphics

/// Cross-app element inspector using the macOS Accessibility API.
/// Requires the Accessibility permission (System Settings > Privacy > Accessibility).
@MainActor
public enum GlobalInspector {
    public static func inspect(at screenPoint: CGPoint) -> InspectionResult {
        // AXUIElementCopyElementAtPosition uses Quartz coordinates (origin top-left).
        let quartzPoint = CoordinateMapper.quartzPoint(fromAppKitScreenPoint: screenPoint)

        let systemWide = AXUIElementCreateSystemWide()
        var elementRef: AXUIElement?
        let err = AXUIElementCopyElementAtPosition(systemWide, Float(quartzPoint.x), Float(quartzPoint.y), &elementRef)

        guard err == .success, let element = elementRef else {
            return InspectionResult(
                screenFrame: CGRect(origin: screenPoint, size: CGSize(width: 1, height: 1)),
                cursorPoint: screenPoint,
                metadata: GrabPayload.GrabMetadata(),
                hierarchyNodes: []
            )
        }

        let frame = axFrame(element) ?? CGRect(origin: screenPoint, size: CGSize(width: 1, height: 1))
        let nodes = buildHierarchy(from: element)
        let metadata = buildMetadata(from: element, hierarchy: nodes.map(\.description))

        return InspectionResult(
            screenFrame: frame,
            cursorPoint: screenPoint,
            metadata: metadata,
            hierarchyNodes: nodes
        )
    }

    // MARK: - AX attribute helpers

    private static func axString(_ element: AXUIElement, _ attribute: String) -> String? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success else { return nil }
        return value as? String
    }

    private static func axFrame(_ element: AXUIElement) -> CGRect? {
        var posRef: CFTypeRef?
        var sizeRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXPositionAttribute as CFString, &posRef) == .success,
              AXUIElementCopyAttributeValue(element, kAXSizeAttribute as CFString, &sizeRef) == .success
        else { return nil }

        var position = CGPoint.zero
        var size = CGSize.zero
        guard AXValueGetValue(posRef as! AXValue, .cgPoint, &position),
              AXValueGetValue(sizeRef as! AXValue, .cgSize, &size)
        else { return nil }

        // AX returns Quartz coordinates — convert to AppKit screen coords.
        let quartzRect = CGRect(origin: position, size: size)
        return CoordinateMapper.appKitRect(fromQuartzRect: quartzRect)
    }

    private static func axParent(_ element: AXUIElement) -> AXUIElement? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXParentAttribute as CFString, &value) == .success else { return nil }
        // The parent is an AXUIElement (which is a CFTypeRef)
        return (value as! AXUIElement)
    }

    private static func axPid(_ element: AXUIElement) -> pid_t? {
        var pid: pid_t = 0
        guard AXUIElementGetPid(element, &pid) == .success else { return nil }
        return pid
    }

    // MARK: - Hierarchy

    private static func buildHierarchy(from element: AXUIElement) -> [HierarchyNode] {
        var nodes: [HierarchyNode] = []
        var current: AXUIElement? = element

        while let el = current {
            let desc = describeElement(el)
            let frame = axFrame(el) ?? .zero
            nodes.append(HierarchyNode(description: desc, screenFrame: frame))

            let role = axString(el, kAXRoleAttribute)
            // Stop at the application level
            if role == kAXApplicationRole as String {
                break
            }
            current = axParent(el)
        }

        return nodes
    }

    private static func describeElement(_ element: AXUIElement) -> String {
        let role = axString(element, kAXRoleAttribute)
        let title = axString(element, kAXTitleAttribute)
        let description = axString(element, kAXDescriptionAttribute)

        let typeName: String
        if let role {
            typeName = role.hasPrefix("AX") ? String(role.dropFirst(2)) : role
        } else {
            typeName = "Unknown"
        }

        let displayName = title ?? description
        if let displayName, !displayName.isEmpty {
            return "\(typeName) \"\(displayName)\""
        }
        return typeName
    }

    // MARK: - Metadata

    private static func buildMetadata(from element: AXUIElement, hierarchy: [String]) -> GrabPayload.GrabMetadata {
        let role = axString(element, kAXRoleAttribute)
        let title = axString(element, kAXTitleAttribute)
        let value = axString(element, kAXValueAttribute)
        let description = axString(element, kAXDescriptionAttribute)

        // Get app info from PID
        var bundleID: String?
        var pid: Int32?
        var windowTitle: String?

        if let p = axPid(element) {
            pid = p
            if let app = NSRunningApplication(processIdentifier: p) {
                bundleID = app.bundleIdentifier
            }
            // Walk up to find the window title
            windowTitle = findWindowTitle(from: element)
        }

        let elementDesc = describeElement(element)

        return GrabPayload.GrabMetadata(
            appBundleIdentifier: bundleID,
            processIdentifier: pid,
            windowTitle: windowTitle,
            viewType: nil,
            accessibilityRole: role,
            accessibilityTitle: title ?? description,
            accessibilityValue: value,
            elementDescription: elementDesc,
            viewHierarchy: hierarchy
        )
    }

    private static func findWindowTitle(from element: AXUIElement) -> String? {
        var current: AXUIElement? = element
        while let el = current {
            let role = axString(el, kAXRoleAttribute)
            if role == kAXWindowRole as String {
                return axString(el, kAXTitleAttribute)
            }
            if role == kAXApplicationRole as String {
                break
            }
            current = axParent(el)
        }
        return nil
    }
}
