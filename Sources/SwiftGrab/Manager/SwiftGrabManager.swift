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
    @Published var permissionMessage: String?
    @Published var regionSizeText: String?
    @Published var statusText: String = "Element mode: click a target to capture."
    @Published var lastCaptureFrame: CGRect?

    private var selectionTool: SelectionTool = .element
    private var overlayController = GrabOverlayWindowController()
    private var trackingMonitor: Any?
    private var keyMonitor: Any?
    private var lastPayload: GrabPayload?
    private var captureHandler: (@MainActor (GrabPayload) -> Void)?
    private(set) var currentMode: GrabMode?
    private var regionDragStart: CGPoint?

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
        regionSizeText = nil
        lastCaptureFrame = nil
        statusText = "Element mode: click a target to capture."
        currentMode = nil
    }

    public func onPayloadCaptured(_ handler: @MainActor @escaping (GrabPayload) -> Void) {
        self.captureHandler = handler
    }

    func setSelectionTool(_ tool: SelectionTool) {
        selectionTool = tool
        regionDragStart = nil
        regionSizeText = nil
        lastCaptureFrame = nil
        statusText = tool == .element
            ? "Element mode: click a target to capture."
            : "Region mode: click first corner, then opposite corner."
    }

    var isRegionToolSelected: Bool {
        selectionTool == .region
    }

    func handleClick(atOverlayPoint point: CGPoint) {
        guard let panel = NSApp.windows.first(where: { $0 is NSPanel }) else { return }
        let screenPoint = panel.convertPoint(toScreen: point)
        switch selectionTool {
        case .element:
            capture(at: screenPoint)
        case .region:
            handleRegionPointClick(at: screenPoint)
        }
    }

    func handleRegionDragChanged(atOverlayPoint point: CGPoint) {
        guard selectionTool == .region else { return }
        guard let panel = NSApp.windows.first(where: { $0 is NSPanel }) else { return }
        let screenPoint = panel.convertPoint(toScreen: point)
        if regionDragStart == nil {
            hoverFrame = CGRect(x: screenPoint.x - 1, y: screenPoint.y - 1, width: 2, height: 2)
            regionSizeText = nil
            return
        }
        if let start = regionDragStart {
            let rect = normalizedRect(from: start, to: screenPoint)
            hoverFrame = rect
            regionSizeText = "\(Int(rect.width)) × \(Int(rect.height))"
        }
    }

    func handleRegionDragEnded(atOverlayPoint point: CGPoint) {
        _ = point
    }

    func copyLastPayloadToClipboard() {
        guard let payload = lastPayload, let json = try? payload.toJSON(prettyPrinted: true) else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(json, forType: .string)
        statusText = "Payload copied to clipboard."
    }

    func sendLastPayloadToAI() {
        copyLastPayloadToClipboard()
        statusText = "Payload copied. Paste into your AI prompt."
    }

    func retakeSelection() {
        lastCaptureFrame = nil
        statusText = selectionTool == .element
            ? "Element mode: click a target to capture."
            : "Region mode: click first corner, then opposite corner."
    }

    private func installMouseTracking() {
        trackingMonitor = NSEvent.addLocalMonitorForEvents(matching: [.mouseMoved]) { [weak self] event in
            Task { @MainActor in
                self?.updateHover(for: event.locationInWindow)
            }
            return event
        }
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { [weak self] event in
            guard event.keyCode == 53 else { return event } // ESC
            Task { @MainActor in
                self?.cancelRegionDrag()
            }
            return nil
        }
    }

    private func uninstallTracking() {
        if let trackingMonitor {
            NSEvent.removeMonitor(trackingMonitor)
        }
        trackingMonitor = nil
        if let keyMonitor {
            NSEvent.removeMonitor(keyMonitor)
        }
        keyMonitor = nil
    }

    private func updateHover(for screenPoint: CGPoint) {
        switch selectionTool {
        case .element:
            hoverFrame = AppLocalInspector.inspect(at: screenPoint).screenFrame
        case .region:
            if regionDragStart == nil {
                hoverFrame = CGRect(x: screenPoint.x - 1, y: screenPoint.y - 1, width: 2, height: 2)
            }
        }
    }

    private func cancelRegionDrag() {
        regionDragStart = nil
        regionSizeText = nil
        lastCaptureFrame = nil
        statusText = "Region selection cancelled."
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
        Task { @MainActor in
            var base64: String?
            do {
                base64 = try await ScreenshotCapturer.capturePNGBase64(in: frame)
                permissionMessage = nil
            } catch GrabCaptureError.screenRecordingPermissionRequired {
                permissionMessage = "Grant Screen Recording in System Settings > Privacy & Security."
                errors.append(GrabCaptureError.screenRecordingPermissionRequired.localizedDescription)
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
            lastCaptureFrame = frame
            statusText = "Captured element. Copy payload or pick again."
            captureHandler?(payload)
        }
    }

    private func capture(regionRect: CGRect, cursorPoint: CGPoint) {
        let metadata = GrabPayload.GrabMetadata(
            appBundleIdentifier: Bundle.main.bundleIdentifier,
            processIdentifier: ProcessInfo.processInfo.processIdentifier
        )
        Task { @MainActor in
            var errors: [String] = []
            var base64: String?
            do {
                base64 = try await ScreenshotCapturer.capturePNGBase64(in: regionRect)
                permissionMessage = nil
            } catch GrabCaptureError.screenRecordingPermissionRequired {
                permissionMessage = "Grant Screen Recording in System Settings > Privacy & Security."
                errors.append(GrabCaptureError.screenRecordingPermissionRequired.localizedDescription)
            } catch {
                errors.append(error.localizedDescription)
            }

            let payload = GrabPayload(
                mode: .appLocal,
                screenFrame: regionRect,
                cursorPoint: cursorPoint,
                userNote: userNote.isEmpty ? nil : userNote,
                metadata: metadata,
                screenshotPNGBase64: base64,
                errors: errors
            )
            lastPayload = payload
            lastCaptureFrame = regionRect
            statusText = "Captured region. Copy payload or pick again."
            captureHandler?(payload)
        }
    }

    func requestScreenRecordingPermission() {
        if CGPreflightScreenCaptureAccess() {
            permissionMessage = nil
            return
        }
        _ = CGRequestScreenCaptureAccess()
        permissionMessage = "If denied, enable Screen Recording for this app in System Settings."
    }

    private func normalizedRect(from start: CGPoint, to end: CGPoint) -> CGRect {
        CGRect(
            x: min(start.x, end.x),
            y: min(start.y, end.y),
            width: abs(end.x - start.x),
            height: abs(end.y - start.y)
        )
    }

    private func handleRegionPointClick(at screenPoint: CGPoint) {
        if regionDragStart == nil {
            regionDragStart = screenPoint
            hoverFrame = CGRect(x: screenPoint.x - 1, y: screenPoint.y - 1, width: 2, height: 2)
            regionSizeText = nil
            statusText = "Now click opposite corner to capture."
            return
        }
        let start = regionDragStart ?? screenPoint
        let rect = normalizedRect(from: start, to: screenPoint)
        regionDragStart = nil
        hoverFrame = rect
        regionSizeText = nil
        guard rect.width > 2, rect.height > 2 else {
            statusText = "Region too small. Try again."
            return
        }
        capture(regionRect: rect, cursorPoint: screenPoint)
    }
}
