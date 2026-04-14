import AppKit
import SwiftUI

@MainActor
public final class SwiftGrabManager: ObservableObject {
    public static let shared = SwiftGrabManager()

    public enum SelectionTool {
        case element
        case region
    }

    @Published var hoverFrame: CGRect?
    @Published var userNote: String = ""

    private var selectionTool: SelectionTool = .element
    private var overlayController = GrabOverlayWindowController()
    private var trackingMonitor: Any?
    private var lastPayload: GrabPayload?
    private var captureHandler: (@MainActor (GrabPayload) -> Void)?
    private(set) var currentMode: GrabMode?

    public init() {}

    public func start(mode: GrabMode = .appLocal) {
        guard currentMode == nil else { return }
        currentMode = mode
        overlayController.present(with: self)
        installMouseTracking()
    }

    public func stop() {
        uninstallTracking()
        overlayController.dismiss()
        hoverFrame = nil
        currentMode = nil
    }

    public func onPayloadCaptured(_ handler: @MainActor @escaping (GrabPayload) -> Void) {
        self.captureHandler = handler
    }

    func setSelectionTool(_ tool: SelectionTool) {
        selectionTool = tool
    }

    func handleClick(atOverlayPoint point: CGPoint) {
        guard let panel = NSApp.windows.first(where: { $0 is NSPanel }) else { return }
        let screenPoint = panel.convertPoint(toScreen: point)
        capture(at: screenPoint)
    }

    func copyLastPayloadToClipboard() {
        guard let payload = lastPayload, let json = try? payload.toJSON(prettyPrinted: true) else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(json, forType: .string)
    }

    private func installMouseTracking() {
        trackingMonitor = NSEvent.addLocalMonitorForEvents(matching: [.mouseMoved]) { [weak self] event in
            Task { @MainActor in
                self?.updateHover(for: event.locationInWindow)
            }
            return event
        }
    }

    private func uninstallTracking() {
        if let trackingMonitor {
            NSEvent.removeMonitor(trackingMonitor)
        }
        trackingMonitor = nil
    }

    private func updateHover(for screenPoint: CGPoint) {
        switch selectionTool {
        case .element:
            hoverFrame = AppLocalInspector.inspect(at: screenPoint).screenFrame
        case .region:
            hoverFrame = CGRect(x: screenPoint.x - 90, y: screenPoint.y - 60, width: 180, height: 120)
        }
    }

    private func capture(at screenPoint: CGPoint) {
        let frame: CGRect
        let inspection: AppLocalInspectionResult
        switch selectionTool {
        case .element:
            inspection = AppLocalInspector.inspect(at: screenPoint)
            frame = inspection.screenFrame
        case .region:
            frame = hoverFrame ?? CGRect(x: screenPoint.x - 90, y: screenPoint.y - 60, width: 180, height: 120)
            inspection = AppLocalInspectionResult(
                screenFrame: frame,
                cursorPoint: screenPoint,
                metadata: GrabPayload.GrabMetadata(
                    appBundleIdentifier: Bundle.main.bundleIdentifier,
                    processIdentifier: ProcessInfo.processInfo.processIdentifier
                )
            )
        }

        var errors: [String] = []
        var base64: String?
        do {
            base64 = try ScreenshotCapturer.capturePNGBase64(in: frame)
        } catch {
            errors.append(error.localizedDescription)
        }

        let payload = GrabPayload(
            mode: .appLocal,
            screenFrame: frame,
            cursorPoint: inspection.cursorPoint,
            userNote: userNote.isEmpty ? nil : userNote,
            metadata: inspection.metadata,
            screenshotPNGBase64: base64,
            errors: errors
        )
        lastPayload = payload
        captureHandler?(payload)
    }
}
