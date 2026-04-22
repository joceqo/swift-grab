import AppKit
import CoreGraphics
import Testing
@testable import SwiftGrab

// Helpers

private let screenSize = CGSize(width: 1512, height: 982)

private func windowDict(
    pid: pid_t,
    layer: Int,
    bounds: CGRect,
    alpha: Double = 1.0,
    ownerName: String? = nil,
    windowName: String? = nil
) -> [String: Any] {
    var dict: [String: Any] = [
        kCGWindowOwnerPID as String: NSNumber(value: pid),
        kCGWindowLayer as String: NSNumber(value: layer),
        kCGWindowBounds as String: [
            "X": bounds.origin.x,
            "Y": bounds.origin.y,
            "Width": bounds.width,
            "Height": bounds.height
        ],
        kCGWindowAlpha as String: NSNumber(value: alpha)
    ]
    if let ownerName { dict[kCGWindowOwnerName as String] = ownerName }
    if let windowName { dict[kCGWindowName as String] = windowName }
    return dict
}

private func match(
    in windows: [[String: Any]],
    at point: CGPoint,
    ownPID: pid_t = 999,
    bundleIDLookup: @escaping (pid_t) -> String? = { _ in nil }
) -> WindowHitTester.Hit? {
    WindowHitTester.firstMatch(
        in: windows,
        at: point,
        ownPID: ownPID,
        screenSize: screenSize,
        bundleIDLookup: bundleIDLookup
    )
}

// MARK: - Tests

@Test
func ownProcessWindowIsSkipped() {
    let windows = [
        windowDict(pid: 999, layer: 0, bounds: CGRect(x: 0, y: 0, width: 500, height: 500), ownerName: "SwiftGrab"),
        windowDict(pid: 42, layer: 0, bounds: CGRect(x: 0, y: 0, width: 500, height: 500), ownerName: "Target")
    ]
    let hit = match(in: windows, at: CGPoint(x: 100, y: 100))
    #expect(hit?.pid == 42)
}

@Test
func frontmostWindowInZOrderWins() {
    // CGWindowList is front-to-back; first match in the array should win.
    let windows = [
        windowDict(pid: 1, layer: 0, bounds: CGRect(x: 0, y: 0, width: 500, height: 500), ownerName: "Front"),
        windowDict(pid: 2, layer: 0, bounds: CGRect(x: 0, y: 0, width: 500, height: 500), ownerName: "Back")
    ]
    let hit = match(in: windows, at: CGPoint(x: 100, y: 100))
    #expect(hit?.pid == 1)
}

@Test
func zeroAlphaHelperIsSkipped() {
    let windows = [
        windowDict(pid: 1, layer: 0, bounds: CGRect(x: 0, y: 0, width: 500, height: 500), alpha: 0, ownerName: "Invisible"),
        windowDict(pid: 2, layer: 0, bounds: CGRect(x: 0, y: 0, width: 500, height: 500), ownerName: "Target")
    ]
    let hit = match(in: windows, at: CGPoint(x: 100, y: 100))
    #expect(hit?.pid == 2)
}

@Test
func screenWideHighLayerHelperIsSkipped() {
    // Clicky's OverlayWindow at level .screenSaver (1000) covering the full screen.
    let windows = [
        windowDict(pid: 1, layer: 1000, bounds: CGRect(origin: .zero, size: screenSize), ownerName: "Clicky"),
        windowDict(pid: 2, layer: 0, bounds: CGRect(x: 0, y: 0, width: 500, height: 500), ownerName: "Target")
    ]
    let hit = match(in: windows, at: CGPoint(x: 100, y: 100))
    #expect(hit?.pid == 2)
}

@Test
func smallHighLayerPopupIsAccepted() {
    // A small (≤90% coverage) window at layer 1000 is a real popup, not a helper.
    let windows = [
        windowDict(pid: 1, layer: 1000, bounds: CGRect(x: 100, y: 100, width: 300, height: 400), ownerName: "RealPopup"),
        windowDict(pid: 2, layer: 0, bounds: CGRect(x: 0, y: 0, width: 1000, height: 1000), ownerName: "Background")
    ]
    let hit = match(in: windows, at: CGPoint(x: 200, y: 200))
    #expect(hit?.pid == 1)
}

@Test
func pointOutsideBoundsIsSkipped() {
    let windows = [
        windowDict(pid: 1, layer: 0, bounds: CGRect(x: 0, y: 0, width: 100, height: 100), ownerName: "Small"),
        windowDict(pid: 2, layer: 0, bounds: CGRect(x: 0, y: 0, width: 500, height: 500), ownerName: "Larger")
    ]
    let hit = match(in: windows, at: CGPoint(x: 200, y: 200))
    #expect(hit?.pid == 2)
}

@Test
func blockedBundleIDIsSkipped() {
    let windows = [
        windowDict(pid: 1, layer: 24, bounds: CGRect(x: 0, y: 0, width: 500, height: 500), ownerName: "Capture d’écran"),
        windowDict(pid: 2, layer: 0, bounds: CGRect(x: 0, y: 0, width: 500, height: 500), ownerName: "Target")
    ]
    let hit = match(
        in: windows,
        at: CGPoint(x: 100, y: 100),
        bundleIDLookup: { pid in pid == 1 ? "com.apple.screencaptureui" : nil }
    )
    #expect(hit?.pid == 2)
}

@Test
func blockedOwnerNameIsSkipped() {
    let windows = [
        windowDict(pid: 1, layer: 0, bounds: CGRect(x: 0, y: 0, width: 500, height: 500), ownerName: "WindowServer"),
        windowDict(pid: 2, layer: 0, bounds: CGRect(x: 0, y: 0, width: 500, height: 500), ownerName: "Target")
    ]
    let hit = match(in: windows, at: CGPoint(x: 100, y: 100))
    #expect(hit?.pid == 2)
}

@Test
func cursorOverNothingReturnsNil() {
    let windows = [
        windowDict(pid: 1, layer: 0, bounds: CGRect(x: 0, y: 0, width: 100, height: 100), ownerName: "A"),
        windowDict(pid: 2, layer: 0, bounds: CGRect(x: 0, y: 0, width: 200, height: 200), ownerName: "B")
    ]
    let hit = match(in: windows, at: CGPoint(x: 500, y: 500))
    #expect(hit == nil)
}

@Test
func clickyMenuBarPanelAtLayer3IsAccepted() {
    // Regression: a menu-bar dropdown panel (NSPanel at .floating = 3) from a
    // non-frontmost accessory app should still be inspectable when the user
    // hovers it. Previously a "frontmost only" rule rejected it.
    let windows = [
        windowDict(pid: 1, layer: 3, bounds: CGRect(x: 1000, y: 0, width: 300, height: 500), ownerName: "Clicky", windowName: "Clicky Panel"),
        windowDict(pid: 2, layer: 0, bounds: CGRect(x: 0, y: 0, width: 1400, height: 900), ownerName: "Cursor")
    ]
    let hit = match(in: windows, at: CGPoint(x: 1100, y: 200))
    #expect(hit?.pid == 1)
    #expect(hit?.ownerName == "Clicky")
    #expect(hit?.windowTitle == "Clicky Panel")
}

@Test
func menuBarItemAtLayer24IsAccepted() {
    // Top-bar menu items live at layer 24 (mainMenu) under controlcenter / apps.
    let windows = [
        windowDict(pid: 1, layer: 24, bounds: CGRect(x: 1090, y: 0, width: 22, height: 24), ownerName: "Control Center")
    ]
    let hit = match(in: windows, at: CGPoint(x: 1100, y: 10))
    #expect(hit?.pid == 1)
}

@Test
func popUpMenuAtLayer101IsAccepted() {
    // Wi-Fi / Dayflow popovers live at popUpMenu = 101.
    let windows = [
        windowDict(pid: 1, layer: 101, bounds: CGRect(x: 500, y: 50, width: 400, height: 500), ownerName: "Popover")
    ]
    let hit = match(in: windows, at: CGPoint(x: 600, y: 150))
    #expect(hit?.pid == 1)
}

@Test
func multipleHelpersInChainAllSkipped() {
    // Three automation-style helpers stacked above the real target.
    let screenRect = CGRect(origin: .zero, size: screenSize)
    let windows = [
        windowDict(pid: 10, layer: 1000, bounds: screenRect, ownerName: "Automation1"),
        windowDict(pid: 11, layer: 500, bounds: screenRect, ownerName: "Automation2"),
        windowDict(pid: 12, layer: 1500, bounds: screenRect, ownerName: "Automation3"),
        windowDict(pid: 42, layer: 0, bounds: CGRect(x: 0, y: 0, width: 800, height: 600), ownerName: "Target")
    ]
    let hit = match(in: windows, at: CGPoint(x: 100, y: 100))
    #expect(hit?.pid == 42)
}

@Test
func screenWideWindowAtLayer0IsKeptAsRegularBackground() {
    // Full-screen layer-0 window (a maximized app) should NOT be treated as a helper.
    let screenRect = CGRect(origin: .zero, size: screenSize)
    let windows = [
        windowDict(pid: 1, layer: 0, bounds: screenRect, ownerName: "FullscreenApp")
    ]
    let hit = match(in: windows, at: CGPoint(x: 100, y: 100))
    #expect(hit?.pid == 1)
}

@Test
func cursorOnBoundaryIsContained() {
    // CGRect.contains includes the origin edge.
    let windows = [
        windowDict(pid: 1, layer: 0, bounds: CGRect(x: 100, y: 100, width: 200, height: 200), ownerName: "App")
    ]
    let hit = match(in: windows, at: CGPoint(x: 100, y: 100))
    #expect(hit?.pid == 1)
}

@Test
func missingLayerDefaultsToZero() {
    // A window dict without kCGWindowLayer should be treated as layer 0.
    var dict: [String: Any] = [
        kCGWindowOwnerPID as String: NSNumber(value: 1 as Int32),
        kCGWindowBounds as String: [
            "X": 0.0, "Y": 0.0, "Width": 500.0, "Height": 500.0
        ],
        kCGWindowAlpha as String: NSNumber(value: 1.0)
    ]
    dict[kCGWindowOwnerName as String] = "App"
    let hit = match(in: [dict], at: CGPoint(x: 100, y: 100))
    #expect(hit?.pid == 1)
}

@Test
func missingBoundsIsSkipped() {
    // Without bounds we can't decide containment — skip.
    let dict: [String: Any] = [
        kCGWindowOwnerPID as String: NSNumber(value: 1 as Int32),
        kCGWindowLayer as String: NSNumber(value: 0),
        kCGWindowAlpha as String: NSNumber(value: 1.0),
        kCGWindowOwnerName as String: "Weird"
    ]
    let hit = match(in: [dict], at: CGPoint(x: 100, y: 100))
    #expect(hit == nil)
}

@Test
func missingPIDIsSkipped() {
    let dict: [String: Any] = [
        kCGWindowLayer as String: NSNumber(value: 0),
        kCGWindowBounds as String: ["X": 0.0, "Y": 0.0, "Width": 100.0, "Height": 100.0],
        kCGWindowAlpha as String: NSNumber(value: 1.0)
    ]
    let hit = match(in: [dict], at: CGPoint(x: 50, y: 50))
    #expect(hit == nil)
}

@Test
func blockedBundleIDBeatsZOrder() {
    // The topmost window in z-order is a blocked system overlay — skipped.
    let windows = [
        windowDict(pid: 1, layer: 24, bounds: CGRect(x: 0, y: 0, width: 500, height: 500), ownerName: "Top"),
        windowDict(pid: 2, layer: 0, bounds: CGRect(x: 0, y: 0, width: 500, height: 500), ownerName: "Beneath")
    ]
    let hit = match(
        in: windows,
        at: CGPoint(x: 100, y: 100),
        bundleIDLookup: { pid in pid == 1 ? "com.apple.screencaptureui" : nil }
    )
    #expect(hit?.pid == 2)
}

@Test
func zeroScreenSizeDoesNotTrigger90PercentHelper() {
    // When screenSize is zero (no main screen), coverage can't be computed and
    // we should still accept the window rather than silently skipping.
    let windows = [
        windowDict(pid: 1, layer: 1000, bounds: CGRect(x: 0, y: 0, width: 500, height: 500), ownerName: "Popup")
    ]
    let hit = WindowHitTester.firstMatch(
        in: windows,
        at: CGPoint(x: 100, y: 100),
        ownPID: 999,
        screenSize: .zero,
        bundleIDLookup: { _ in nil }
    )
    #expect(hit?.pid == 1)
}

@Test
func partialCoverageHighLayerIsAccepted() {
    // 50% coverage at layer 1000 is a real popup, not a helper.
    let halfScreen = CGRect(x: 0, y: 0, width: screenSize.width * 0.5, height: screenSize.height)
    let windows = [
        windowDict(pid: 1, layer: 1000, bounds: halfScreen, ownerName: "HalfPopup")
    ]
    let hit = match(in: windows, at: CGPoint(x: 100, y: 100))
    #expect(hit?.pid == 1)
}

@Test
func hitEquatableSupportsDeduplication() {
    let a = WindowHitTester.Hit(pid: 1, ownerName: "A", windowTitle: "W")
    let b = WindowHitTester.Hit(pid: 1, ownerName: "A", windowTitle: "W")
    let c = WindowHitTester.Hit(pid: 2, ownerName: "A", windowTitle: "W")
    #expect(a == b)
    #expect(a != c)
}
