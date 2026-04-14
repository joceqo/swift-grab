import AppKit
import CoreGraphics
import ScreenCaptureKit

enum ScreenshotCapturer {
    static func capturePNGBase64(in screenRect: CGRect) async throws -> String {
        // Clamp in AppKit screen coordinates
        let safeRect = CoordinateMapper.clampToVisibleScreens(screenRect)
        guard !safeRect.isNull, !safeRect.isEmpty else {
            throw GrabCaptureError.emptySelection
        }

        guard CGPreflightScreenCaptureAccess() else {
            throw GrabCaptureError.screenRecordingPermissionRequired
        }

        // Convert to Quartz coordinates for ScreenCaptureKit
        let quartzRect = CoordinateMapper.quartzRect(fromAppKitScreenRect: safeRect)

        let content = try await SCShareableContent.current

        // SCDisplay.frame uses Quartz coordinates — compare in the same space
        guard let display = content.displays
            .max(by: { $0.frame.intersection(quartzRect).area < $1.frame.intersection(quartzRect).area }),
            display.frame.intersection(quartzRect).area > 0
        else {
            throw GrabCaptureError.screenshotFailed
        }

        // Local rect relative to the display's origin (Quartz)
        let localRect = quartzRect.offsetBy(dx: -display.frame.minX, dy: -display.frame.minY)

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
