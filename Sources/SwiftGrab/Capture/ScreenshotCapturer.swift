import AppKit
import CoreGraphics
import ScreenCaptureKit

enum ScreenshotCapturer {
    static func capturePNGBase64(in screenRect: CGRect) async throws -> String {
        let safeRect = CoordinateMapper.clampToVisibleScreens(screenRect)
        guard !safeRect.isNull, !safeRect.isEmpty else {
            throw GrabCaptureError.emptySelection
        }

        guard CGPreflightScreenCaptureAccess() else {
            throw GrabCaptureError.screenRecordingPermissionRequired
        }

        let content = try await SCShareableContent.current
        let displayAndFrame = content.displays
            .map { display in
                (
                    display,
                    CGRect(
                        x: display.frame.origin.x,
                        y: display.frame.origin.y,
                        width: CGFloat(display.width),
                        height: CGFloat(display.height)
                    )
                )
            }
            .max { lhs, rhs in
                let lhsArea = lhs.1.intersection(safeRect).area
                let rhsArea = rhs.1.intersection(safeRect).area
                return lhsArea < rhsArea
            }

        guard let (display, displayFrame) = displayAndFrame,
              displayFrame.intersection(safeRect).area > 0
        else {
            throw GrabCaptureError.screenshotFailed
        }

        let localRect = safeRect.offsetBy(dx: -displayFrame.minX, dy: -displayFrame.minY)

        let filter = SCContentFilter(display: display, excludingApplications: [], exceptingWindows: [])
        let configuration = SCStreamConfiguration()
        configuration.width = Int(localRect.width)
        configuration.height = Int(localRect.height)
        configuration.sourceRect = localRect

        let image = try await SCScreenshotManager.captureImage(
            contentFilter: filter,
            configuration: configuration
        )

        let bitmap = NSBitmapImageRep(cgImage: image)
        guard let data = bitmap.representation(using: .png, properties: [:]) else {
            throw GrabCaptureError.screenshotEncodingFailed
        }
        return data.base64EncodedString()
    }
}

private extension CGRect {
    var area: CGFloat {
        guard !isNull, !isEmpty else { return 0 }
        return width * height
    }
}

enum GrabCaptureError: LocalizedError {
    case emptySelection
    case screenshotFailed
    case screenshotEncodingFailed
    case screenRecordingPermissionRequired

    var errorDescription: String? {
        switch self {
        case .emptySelection:
            return "Selection rectangle is empty."
        case .screenshotFailed:
            return "Failed to capture screenshot."
        case .screenshotEncodingFailed:
            return "Failed to encode screenshot as PNG."
        case .screenRecordingPermissionRequired:
            return "Screen recording permission is required to capture screenshots."
        }
    }
}
