import AppKit
import CoreGraphics

enum CoordinateMapper {
    // MARK: - SwiftUI ↔ Screen conversions

    /// SwiftUI overlay point (origin top-left) → AppKit screen point (origin bottom-left).
    static func screenPoint(fromSwiftUIPoint point: CGPoint, overlayScreenFrame: CGRect) -> CGPoint {
        CGPoint(
            x: overlayScreenFrame.origin.x + point.x,
            y: overlayScreenFrame.maxY - point.y
        )
    }

    /// AppKit window-local point (origin bottom-left) → AppKit screen point.
    static func screenPoint(fromWindowPoint point: CGPoint, overlayScreenFrame: CGRect) -> CGPoint {
        CGPoint(
            x: overlayScreenFrame.origin.x + point.x,
            y: overlayScreenFrame.origin.y + point.y
        )
    }

    /// AppKit screen rect → SwiftUI overlay rect (origin top-left).
    static func swiftUIRect(fromScreenRect screenRect: CGRect, overlayScreenFrame: CGRect) -> CGRect {
        CGRect(
            x: screenRect.origin.x - overlayScreenFrame.origin.x,
            y: overlayScreenFrame.maxY - screenRect.maxY,
            width: screenRect.size.width,
            height: screenRect.size.height
        )
    }

    // MARK: - AppKit ↔ Quartz conversions

    /// AppKit screen rect (origin bottom-left of primary) → Quartz/CG rect (origin top-left of primary).
    /// Used when passing rects to ScreenCaptureKit which uses Quartz coordinates.
    static func quartzRect(fromAppKitScreenRect rect: CGRect) -> CGRect {
        guard let primaryHeight = NSScreen.screens.first?.frame.height else { return rect }
        return CGRect(
            x: rect.origin.x,
            y: primaryHeight - rect.origin.y - rect.height,
            width: rect.width,
            height: rect.height
        )
    }

    // MARK: - Utilities

    static func clampToVisibleScreens(_ rect: CGRect) -> CGRect {
        let union = NSScreen.screens.reduce(CGRect.null) { partialResult, screen in
            partialResult.union(screen.frame)
        }
        guard !union.isNull else { return rect }
        return rect.intersection(union)
    }

    static func backingScaledRect(_ rect: CGRect, on screen: NSScreen?) -> CGRect {
        guard let scale = screen?.backingScaleFactor else { return rect }
        return CGRect(
            x: rect.origin.x * scale,
            y: rect.origin.y * scale,
            width: rect.size.width * scale,
            height: rect.size.height * scale
        )
    }
}
