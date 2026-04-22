import AppKit
import ApplicationServices
import CoreGraphics

/// Cross-app element inspector using the macOS Accessibility API.
/// Requires the Accessibility permission (System Settings > Privacy > Accessibility).
@MainActor
public enum GlobalInspector {
    private static let logPrefix = "[SwiftGrab][GlobalInspector]"

    public static func inspect(at screenPoint: CGPoint) -> InspectionResult {
        // AXUIElementCopyElementAtPosition uses Quartz coordinates (origin top-left).
        let quartzPoint = CoordinateMapper.quartzPoint(fromAppKitScreenPoint: screenPoint)

        // Skip SwiftGrab's own windows by picking the topmost foreign window
        // under the cursor, then query AX only against that app.
        guard let hit = WindowHitTester.frontmostForeignWindow(at: quartzPoint) else {
            return emptyResult(at: screenPoint)
        }
        // Defensive: never query our own process even if the hit test let one through.
        guard hit.pid != ProcessInfo.processInfo.processIdentifier else {
            return emptyResult(at: screenPoint)
        }

        let appElement = AXUIElementCreateApplication(hit.pid)
        var elementRef: AXUIElement?
        let err = AXUIElementCopyElementAtPosition(appElement, Float(quartzPoint.x), Float(quartzPoint.y), &elementRef)

        guard err == .success, let element = elementRef else {
            // AX failed (e.g. app refuses inspection). Still report the foreign app so the user sees context.
            return fallbackResult(at: screenPoint, hit: hit)
        }

        // Drill into AX children to find the deepest element containing the cursor.
        // AXUIElementCopyElementAtPosition often returns a container (like AXGroup)
        // even when more specific children exist at the same point.
        let deepest = drillToDeepestChild(from: element, quartzPoint: quartzPoint)

        let frame = axFrame(deepest) ?? CGRect(origin: screenPoint, size: CGSize(width: 1, height: 1))
        let nodes = buildHierarchy(from: deepest)
        let metadata = buildMetadata(from: deepest, hierarchy: nodes.map(\.description))

        return InspectionResult(
            screenFrame: frame,
            cursorPoint: screenPoint,
            metadata: metadata,
            hierarchyNodes: nodes
        )
    }

    private static func emptyResult(at screenPoint: CGPoint) -> InspectionResult {
        InspectionResult(
            screenFrame: CGRect(origin: screenPoint, size: CGSize(width: 1, height: 1)),
            cursorPoint: screenPoint,
            metadata: GrabPayload.GrabMetadata(),
            hierarchyNodes: []
        )
    }

    private static func fallbackResult(at screenPoint: CGPoint, hit: WindowHitTester.Hit) -> InspectionResult {
        let metadata = GrabPayload.GrabMetadata(
            appBundleIdentifier: NSRunningApplication(processIdentifier: hit.pid)?.bundleIdentifier ?? hit.ownerName,
            processIdentifier: hit.pid,
            windowTitle: hit.windowTitle
        )
        return InspectionResult(
            screenFrame: CGRect(origin: screenPoint, size: CGSize(width: 1, height: 1)),
            cursorPoint: screenPoint,
            metadata: metadata,
            hierarchyNodes: []
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

    // MARK: - Drill-down

    private static func axChildren(_ element: AXUIElement) -> [AXUIElement] {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &value) == .success,
              let array = value as? [AXUIElement]
        else { return [] }
        return array
    }

    private static func axQuartzFrame(_ element: AXUIElement) -> CGRect? {
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
        return CGRect(origin: position, size: size)
    }

    /// Walk AX children of `element` that contain `quartzPoint`, preferring smaller
    /// frames and children with identifying info (title / identifier / value). Falls
    /// back to the current element when descending would lose information — so we
    /// keep wrapper-level results when children are opaque to AX.
    private static func drillToDeepestChild(from element: AXUIElement, quartzPoint: CGPoint) -> AXUIElement {
        var current = element
        for _ in 0..<32 {
            let children = axChildren(current)
            guard !children.isEmpty else { break }

            let currentArea = (axQuartzFrame(current).map { $0.width * $0.height }) ?? .greatestFiniteMagnitude
            var best: (element: AXUIElement, score: Int)?

            for child in children {
                guard let frame = axQuartzFrame(child), frame.contains(quartzPoint) else { continue }
                let score = scoreCandidate(child, area: frame.width * frame.height, parentArea: currentArea)
                if best == nil || score > best!.score {
                    best = (child, score)
                }
            }

            // Only descend if the best child is a meaningful improvement.
            guard let next = best, next.score > 0 else { break }
            current = next.element
        }
        return current
    }

    /// Positive score = worth descending. Rewards specificity (smaller frame,
    /// identifier/title/value present). Negative score means the child is a pure
    /// wrapper, so we keep the current element.
    private static func scoreCandidate(_ el: AXUIElement, area: CGFloat, parentArea: CGFloat) -> Int {
        var score = 0
        if axString(el, kAXIdentifierAttribute) != nil { score += 10 }
        if axString(el, kAXTitleAttribute) != nil { score += 5 }
        if axString(el, kAXValueAttribute) != nil { score += 3 }
        if axString(el, kAXDescriptionAttribute) != nil { score += 2 }
        // Smaller frames are more specific.
        if area < parentArea * 0.95 { score += 4 }
        // Role beyond generic wrappers is a mild signal.
        if let role = axString(el, kAXRoleAttribute) {
            let wrappers: Set<String> = ["AXGroup", "AXUnknown", "AXLayoutArea", "AXLayoutItem"]
            if !wrappers.contains(role) { score += 3 }
        }
        return score
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
        let subrole = axString(element, kAXSubroleAttribute)
        let identifier = axString(element, kAXIdentifierAttribute)
        let title = axString(element, kAXTitleAttribute)
        let value = axString(element, kAXValueAttribute)
        let help = axString(element, kAXHelpAttribute)
        let description = axString(element, kAXDescriptionAttribute)
        let selectedText = axString(element, kAXSelectedTextAttribute)
        let url = axURL(element, kAXURLAttribute)

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
            accessibilitySubrole: subrole,
            accessibilityIdentifier: identifier,
            accessibilityTitle: title ?? description,
            accessibilityValue: value,
            accessibilityHelp: help,
            accessibilityURL: url,
            accessibilitySelectedText: selectedText,
            elementDescription: elementDesc,
            viewHierarchy: hierarchy
        )
    }

    private static func axURL(_ element: AXUIElement, _ attribute: String) -> String? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success else { return nil }
        return (value as? URL)?.absoluteString
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

// MARK: - WindowHitTester

/// Filters the on-screen window list to find the topmost visible window under
/// a point, skipping our own process and known invisible helper windows.
@MainActor
enum WindowHitTester {
    struct Hit: Equatable {
        let pid: pid_t
        let ownerName: String?
        let windowTitle: String?
    }

    /// Bundle IDs whose windows we never want to inspect — system overlays
    /// that don't represent user UI the user is thinking about.
    nonisolated static let blockedBundleIDs: Set<String> = [
        "com.apple.screencaptureui",
        "com.apple.WindowManager",
        "com.apple.dock"
    ]

    /// Owner names (language-independent for these — they're server processes).
    nonisolated static let blockedOwnerNames: Set<String> = ["WindowServer"]

    /// `quartzPoint` is in Quartz (top-left origin) coordinates, same basis as `kCGWindowBounds`.
    static func frontmostForeignWindow(at quartzPoint: CGPoint) -> Hit? {
        let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
        guard let windows = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else {
            return nil
        }
        let ownPID = ProcessInfo.processInfo.processIdentifier
        let screenSize = NSScreen.main?.frame.size ?? .zero
        return firstMatch(in: windows, at: quartzPoint, ownPID: ownPID, screenSize: screenSize, bundleIDLookup: { pid in
            NSRunningApplication(processIdentifier: pid)?.bundleIdentifier
        })
    }

    /// Pure hit-test logic, exposed for unit tests. Returns the first window in
    /// front-to-back `windows` that contains `quartzPoint` and isn't filtered.
    nonisolated static func firstMatch(
        in windows: [[String: Any]],
        at quartzPoint: CGPoint,
        ownPID: pid_t,
        screenSize: CGSize,
        bundleIDLookup: (pid_t) -> String?
    ) -> Hit? {
        for window in windows {
            guard let ownerPIDNumber = window[kCGWindowOwnerPID as String] as? NSNumber else { continue }
            let ownerPID = ownerPIDNumber.int32Value
            if ownerPID == ownPID { continue }

            if let bundleID = bundleIDLookup(ownerPID), blockedBundleIDs.contains(bundleID) { continue }
            if let ownerName = window[kCGWindowOwnerName as String] as? String,
               blockedOwnerNames.contains(ownerName) { continue }

            let alpha = (window[kCGWindowAlpha as String] as? NSNumber)?.doubleValue ?? 1.0
            if alpha <= 0.01 { continue }

            guard let boundsDict = window[kCGWindowBounds as String] as? [String: Any],
                  let bounds = CGRect(dictionaryRepresentation: boundsDict as CFDictionary)
            else { continue }
            guard bounds.contains(quartzPoint) else { continue }

            let layer = (window[kCGWindowLayer as String] as? NSNumber)?.intValue ?? 0

            // Screen-wide helper detection: layer > 150 (screensaver-ish) AND
            // bounds cover ≥90% of the screen. Automation/menu-bar apps park
            // invisible trackers there — skip them.
            let coverage = screenSize.width > 0 && screenSize.height > 0
                ? (bounds.width * bounds.height) / (screenSize.width * screenSize.height)
                : 0
            if layer > 150 && coverage > 0.9 { continue }

            return Hit(
                pid: ownerPID,
                ownerName: window[kCGWindowOwnerName as String] as? String,
                windowTitle: window[kCGWindowName as String] as? String
            )
        }
        return nil
    }
}
