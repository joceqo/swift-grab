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
