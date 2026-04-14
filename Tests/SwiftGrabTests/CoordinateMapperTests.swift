import AppKit
import CoreGraphics
import Testing
@testable import SwiftGrab

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

@Test
func overlayPointConvertsToExpectedScreenPoint() {
    let overlayScreenFrame = CGRect(x: 200, y: 120, width: 1200, height: 800)
    let overlayPoint = CGPoint(x: 30, y: 45)

    let screenPoint = CoordinateMapper.screenPoint(
        fromOverlayPoint: overlayPoint,
        overlayScreenFrame: overlayScreenFrame
    )

    #expect(screenPoint.x == 230)
    #expect(screenPoint.y == 165)
}

@Test
func screenRectConvertsToExpectedOverlayRect() {
    let overlayScreenFrame = CGRect(x: 200, y: 120, width: 1200, height: 800)
    let selectedScreenRect = CGRect(x: 260, y: 200, width: 300, height: 180)

    let overlayRect = CoordinateMapper.overlayRect(
        fromScreenRect: selectedScreenRect,
        overlayScreenFrame: overlayScreenFrame
    )

    #expect(overlayRect.origin.x == 60)
    #expect(overlayRect.origin.y == 80)
    #expect(overlayRect.width == 300)
    #expect(overlayRect.height == 180)
}
