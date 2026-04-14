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
}
