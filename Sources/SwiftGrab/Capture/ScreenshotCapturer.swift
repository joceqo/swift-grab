import AppKit
import CoreGraphics

enum ScreenshotCapturer {
    static func capturePNGBase64(in screenRect: CGRect) throws -> String {
        let safeRect = CoordinateMapper.clampToVisibleScreens(screenRect)
        guard !safeRect.isNull, !safeRect.isEmpty else {
            throw GrabCaptureError.emptySelection
        }

        guard let image = CGWindowListCreateImage(
            safeRect,
            .optionOnScreenOnly,
            kCGNullWindowID,
            [.boundsIgnoreFraming, .bestResolution]
        ) else {
            throw GrabCaptureError.screenshotFailed
        }

        let bitmap = NSBitmapImageRep(cgImage: image)
        guard let data = bitmap.representation(using: .png, properties: [:]) else {
            throw GrabCaptureError.screenshotEncodingFailed
        }
        return data.base64EncodedString()
    }
}

enum GrabCaptureError: LocalizedError {
    case emptySelection
    case screenshotFailed
    case screenshotEncodingFailed

    var errorDescription: String? {
        switch self {
        case .emptySelection:
            return "Selection rectangle is empty."
        case .screenshotFailed:
            return "Failed to capture screenshot."
        case .screenshotEncodingFailed:
            return "Failed to encode screenshot as PNG."
        }
    }
}
