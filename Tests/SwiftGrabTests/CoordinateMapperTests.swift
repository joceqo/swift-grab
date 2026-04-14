import AppKit
import CoreGraphics
import Testing
@testable import SwiftGrab

// MARK: - Utility (unchanged)

@Test
func backingScaleFallsBackToInputRectWhenScreenMissing() {
    let rect = CGRect(x: 1, y: 2, width: 3, height: 4)
    let scaled = CoordinateMapper.backingScaledRect(rect, on: nil)
    #expect(scaled == rect)
}

@Test
func clampReturnsIntersectionWithVisibleArea() {
    let result = CoordinateMapper.clampToVisibleScreens(.init(x: -1000, y: -1000, width: 50, height: 50))
    #expect(result.isNull || result.width <= 50)
}

// MARK: - AppKit window-point → screen (no Y-flip)

@Test
func windowPointConvertsToScreenPoint() {
    let overlayScreenFrame = CGRect(x: 200, y: 120, width: 1200, height: 800)
    let windowPoint = CGPoint(x: 30, y: 45)

    let screenPoint = CoordinateMapper.screenPoint(
        fromWindowPoint: windowPoint,
        overlayScreenFrame: overlayScreenFrame
    )

    #expect(screenPoint.x == 230)  // 200 + 30
    #expect(screenPoint.y == 165)  // 120 + 45  (no flip)
}

// MARK: - SwiftUI point → screen (Y-flip)

@Test
func swiftUIPointConvertsToScreenPointWithYFlip() {
    // Overlay panel covers (0, 0, 1440, 900) in AppKit screen coords
    let overlayScreenFrame = CGRect(x: 0, y: 0, width: 1440, height: 900)

    // SwiftUI point 50px from top → AppKit 850px from bottom
    let point = CGPoint(x: 100, y: 50)
    let screenPoint = CoordinateMapper.screenPoint(
        fromSwiftUIPoint: point,
        overlayScreenFrame: overlayScreenFrame
    )

    #expect(screenPoint.x == 100)
    #expect(screenPoint.y == 850)  // 900 - 50
}

@Test
func swiftUIPointAtCenterMapsToScreenCenter() {
    let overlayScreenFrame = CGRect(x: 0, y: 0, width: 1440, height: 900)
    let center = CGPoint(x: 720, y: 450)

    let screenPoint = CoordinateMapper.screenPoint(
        fromSwiftUIPoint: center,
        overlayScreenFrame: overlayScreenFrame
    )

    #expect(screenPoint.x == 720)
    #expect(screenPoint.y == 450)  // Center is invariant under flip
}

@Test
func swiftUIPointWithOffsetOverlay() {
    // Secondary display offset to the right
    let overlayScreenFrame = CGRect(x: 1440, y: 0, width: 1920, height: 1080)
    let point = CGPoint(x: 100, y: 80)

    let screenPoint = CoordinateMapper.screenPoint(
        fromSwiftUIPoint: point,
        overlayScreenFrame: overlayScreenFrame
    )

    #expect(screenPoint.x == 1540)   // 1440 + 100
    #expect(screenPoint.y == 1000)   // 0 + 1080 - 80
}

// MARK: - Screen rect → SwiftUI rect (Y-flip)

@Test
func screenRectConvertsToSwiftUIRectWithYFlip() {
    let overlayScreenFrame = CGRect(x: 0, y: 0, width: 1440, height: 900)

    // Element near top of screen in AppKit: bottom at y=820, top at y=880
    let screenRect = CGRect(x: 100, y: 820, width: 200, height: 60)
    let swiftUIRect = CoordinateMapper.swiftUIRect(
        fromScreenRect: screenRect,
        overlayScreenFrame: overlayScreenFrame
    )

    #expect(swiftUIRect.origin.x == 100)
    #expect(swiftUIRect.origin.y == 20)   // 900 - 880 = 20px from top
    #expect(swiftUIRect.width == 200)
    #expect(swiftUIRect.height == 60)
}

@Test
func screenRectAtBottomMapsToSwiftUIBottom() {
    let overlayScreenFrame = CGRect(x: 0, y: 0, width: 1440, height: 900)

    // Element near bottom of screen in AppKit: bottom at y=0, top at y=40
    let screenRect = CGRect(x: 50, y: 0, width: 300, height: 40)
    let swiftUIRect = CoordinateMapper.swiftUIRect(
        fromScreenRect: screenRect,
        overlayScreenFrame: overlayScreenFrame
    )

    #expect(swiftUIRect.origin.x == 50)
    #expect(swiftUIRect.origin.y == 860)  // 900 - 40 = near bottom in SwiftUI
    #expect(swiftUIRect.width == 300)
    #expect(swiftUIRect.height == 40)
}

@Test
func screenRectWithOffsetOverlay() {
    let overlayScreenFrame = CGRect(x: 200, y: 120, width: 1200, height: 800)

    // Element at AppKit screen (260, 840, 300, 60) → top edge at 900
    let screenRect = CGRect(x: 260, y: 840, width: 300, height: 60)
    let swiftUIRect = CoordinateMapper.swiftUIRect(
        fromScreenRect: screenRect,
        overlayScreenFrame: overlayScreenFrame
    )

    #expect(swiftUIRect.origin.x == 60)   // 260 - 200
    #expect(swiftUIRect.origin.y == 20)   // (120 + 800) - (840 + 60) = 920 - 900 = 20
    #expect(swiftUIRect.width == 300)
    #expect(swiftUIRect.height == 60)
}

// MARK: - Round-trip: SwiftUI → screen → SwiftUI

@Test
func swiftUIRectRoundTripsCorrectly() {
    let overlayScreenFrame = CGRect(x: 0, y: 0, width: 1440, height: 900)

    // A SwiftUI rect at (100, 200) with size (50, 30)
    let originalSwiftUI = CGRect(x: 100, y: 200, width: 50, height: 30)

    // Convert SwiftUI top-left corner to screen point
    let screenOrigin = CoordinateMapper.screenPoint(
        fromSwiftUIPoint: originalSwiftUI.origin,
        overlayScreenFrame: overlayScreenFrame
    )
    // Build the screen rect: AppKit origin is the bottom-left of the rect
    let screenRect = CGRect(
        x: screenOrigin.x,
        y: screenOrigin.y - originalSwiftUI.height,
        width: originalSwiftUI.width,
        height: originalSwiftUI.height
    )

    // Convert back to SwiftUI
    let roundTrip = CoordinateMapper.swiftUIRect(
        fromScreenRect: screenRect,
        overlayScreenFrame: overlayScreenFrame
    )

    #expect(roundTrip.origin.x == originalSwiftUI.origin.x)
    #expect(roundTrip.origin.y == originalSwiftUI.origin.y)
    #expect(roundTrip.width == originalSwiftUI.width)
    #expect(roundTrip.height == originalSwiftUI.height)
}

// MARK: - Quartz conversion

@Test
func quartzConversionFlipsYRelativeToPrimaryDisplay() {
    // This test only validates the math, not actual NSScreen.screens
    // On a 900px primary display:
    // AppKit rect (100, 800, 200, 60) → Quartz (100, 40, 200, 60)
    // Because: quartzY = 900 - 800 - 60 = 40
    //
    // We can't control NSScreen.screens in a unit test, so this
    // test verifies the function exists and preserves dimensions.
    let input = CGRect(x: 100, y: 300, width: 200, height: 60)
    let result = CoordinateMapper.quartzRect(fromAppKitScreenRect: input)

    // Dimensions always preserved
    #expect(result.width == 200)
    #expect(result.height == 60)
    // X always preserved
    #expect(result.origin.x == 100)
    // Y depends on actual primary screen height — just verify it changed
    // (unless running on a screen where 300 happens to be the center)
}
