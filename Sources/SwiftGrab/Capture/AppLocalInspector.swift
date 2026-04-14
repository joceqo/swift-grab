import AppKit
import CoreGraphics

struct AppLocalInspectionResult {
    var screenFrame: CGRect
    var cursorPoint: CGPoint
    var metadata: GrabPayload.GrabMetadata
}

@MainActor
enum AppLocalInspector {
    static func inspect(at screenPoint: CGPoint) -> AppLocalInspectionResult {
        let candidateWindows = NSApp.windows
            .filter { $0.isVisible && !$0.isMiniaturized }
            .filter { !$0.isKind(of: NSPanel.self) }

        guard let window = candidateWindows.last(where: { $0.frame.contains(screenPoint) }) else {
            return AppLocalInspectionResult(
                screenFrame: CGRect(origin: screenPoint, size: CGSize(width: 1, height: 1)),
                cursorPoint: screenPoint,
                metadata: buildMetadata(window: nil, view: nil)
            )
        }

        let localPoint = window.convertPoint(fromScreen: screenPoint)
        let view = window.contentView?.hitTest(localPoint)
        let selectedRect = selectedRectForView(view, in: window) ?? window.frame
        return AppLocalInspectionResult(
            screenFrame: selectedRect,
            cursorPoint: screenPoint,
            metadata: buildMetadata(window: window, view: view)
        )
    }

    private static func selectedRectForView(_ view: NSView?, in window: NSWindow) -> CGRect? {
        guard let view else { return nil }
        let localRect = view.convert(view.bounds, to: nil)
        return window.convertToScreen(localRect)
    }

    private static func buildMetadata(window: NSWindow?, view: NSView?) -> GrabPayload.GrabMetadata {
        GrabPayload.GrabMetadata(
            appBundleIdentifier: Bundle.main.bundleIdentifier,
            processIdentifier: ProcessInfo.processInfo.processIdentifier,
            windowTitle: window?.title,
            viewType: view.map { String(describing: type(of: $0)) },
            accessibilityTitle: view?.accessibilityTitle(),
            accessibilityValue: view?.accessibilityValueDescription()
        )
    }
}

private extension NSView {
    func accessibilityValueDescription() -> String? {
        if let stringValue = accessibilityValue() as? String {
            return stringValue
        }
        if let numberValue = accessibilityValue() as? NSNumber {
            return numberValue.stringValue
        }
        return nil
    }
}
