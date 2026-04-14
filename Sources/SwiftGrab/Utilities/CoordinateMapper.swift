import AppKit
import CoreGraphics

enum CoordinateMapper {
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

    static func screenPoint(fromOverlayPoint overlayPoint: CGPoint, overlayScreenFrame: CGRect) -> CGPoint {
        CGPoint(
            x: overlayScreenFrame.origin.x + overlayPoint.x,
            y: overlayScreenFrame.origin.y + overlayPoint.y
        )
    }

    static func overlayRect(fromScreenRect screenRect: CGRect, overlayScreenFrame: CGRect) -> CGRect {
        CGRect(
            x: screenRect.origin.x - overlayScreenFrame.origin.x,
            y: screenRect.origin.y - overlayScreenFrame.origin.y,
            width: screenRect.size.width,
            height: screenRect.size.height
        )
    }
}
