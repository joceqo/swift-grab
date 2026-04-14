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
    @Published var hoverInfo: String?
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
        hoverInfo = nil
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
        hoverInfo = nil
        lastCaptureFrame = nil
        statusText = tool == .element
            ? "Element mode: click a target to capture."
            : "Region mode: click first corner, then opposite corner."
    }

    var isRegionToolSelected: Bool {
        selectionTool == .region
    }

    // MARK: - SwiftUI gesture entry points

    func handleClick(atSwiftUIPoint point: CGPoint) {
        guard let screenPoint = overlayController.convertSwiftUIPointToScreen(point) else { return }
        switch selectionTool {
        case .element:
            capture(at: screenPoint)
        case .region:
            handleRegionPointClick(at: screenPoint)
        }
    }

    func handleRegionDragChanged(atSwiftUIPoint point: CGPoint) {
        guard selectionTool == .region else { return }
        if regionDragStart == nil {
            // No drag started yet — show crosshair at the raw SwiftUI point
            hoverFrame = CGRect(x: point.x - 1, y: point.y - 1, width: 2, height: 2)
            regionSizeText = nil
            return
        }
        guard let screenPoint = overlayController.convertSwiftUIPointToScreen(point) else { return }
        if let start = regionDragStart {
            let rect = normalizedRect(from: start, to: screenPoint)
            hoverFrame = overlayController.convertScreenRectToSwiftUIRect(rect) ?? .zero
            regionSizeText = "\(Int(rect.width)) × \(Int(rect.height))"
        }
    }

    func handleRegionDragEnded(atSwiftUIPoint point: CGPoint) {
        _ = point
    }

    // MARK: - Clipboard / UI actions

    var lastElementDescription: String? {
        lastPayload?.metadata.elementDescription
    }

    func copyLastPayloadAndClose() {
        guard let payload = lastPayload, let json = try? payload.toJSON(prettyPrinted: true) else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(json, forType: .string)
        stop()
    }

    func retakeSelection() {
        lastCaptureFrame = nil
        overlayController.setAcceptsKeyInput(false)
        statusText = selectionTool == .element
            ? "Element mode: click a target to capture."
            : "Region mode: click first corner, then opposite corner."
    }

    // MARK: - Mouse / key tracking (AppKit events)

    private func installMouseTracking() {
        trackingMonitor = NSEvent.addLocalMonitorForEvents(matching: [.mouseMoved]) { [weak self] event in
            Task { @MainActor in
                guard let self else { return }
                // NSEvent.locationInWindow is in AppKit window coords (origin bottom-left)
                guard let screenPoint = self.overlayController.convertWindowPointToScreen(event.locationInWindow) else { return }
                self.updateHover(for: screenPoint)
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
        // Don't update hover while the post-capture panel is showing.
        guard lastCaptureFrame == nil else { return }
        switch selectionTool {
        case .element:
            let inspection = AppLocalInspector.inspect(at: screenPoint)
            hoverFrame = overlayController.convertScreenRectToSwiftUIRect(inspection.screenFrame)
            hoverInfo = inspection.metadata.elementDescription
        case .region:
            if regionDragStart == nil {
                if let swiftUIPoint = swiftUIPoint(fromScreenPoint: screenPoint) {
                    hoverFrame = CGRect(x: swiftUIPoint.x - 1, y: swiftUIPoint.y - 1, width: 2, height: 2)
                }
            }
        }
    }

    private func cancelRegionDrag() {
        regionDragStart = nil
        regionSizeText = nil
        lastCaptureFrame = nil
        statusText = "Region selection cancelled."
    }

    // MARK: - Capture

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
            lastCaptureFrame = overlayController.convertScreenRectToSwiftUIRect(frame)
            hoverInfo = nil
            overlayController.setAcceptsKeyInput(true)
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
            lastCaptureFrame = overlayController.convertScreenRectToSwiftUIRect(regionRect)
            hoverInfo = nil
            overlayController.setAcceptsKeyInput(true)
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

    // MARK: - Region helpers

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
            if let swiftUIPoint = swiftUIPoint(fromScreenPoint: screenPoint) {
                hoverFrame = CGRect(x: swiftUIPoint.x - 1, y: swiftUIPoint.y - 1, width: 2, height: 2)
            }
            regionSizeText = nil
            statusText = "Now click opposite corner to capture."
            return
        }
        let start = regionDragStart ?? screenPoint
        let rect = normalizedRect(from: start, to: screenPoint)
        regionDragStart = nil
        hoverFrame = overlayController.convertScreenRectToSwiftUIRect(rect)
        regionSizeText = nil
        guard rect.width > 2, rect.height > 2 else {
            statusText = "Region too small. Try again."
            return
        }
        capture(regionRect: rect, cursorPoint: screenPoint)
    }

    /// Convert an AppKit screen point to a SwiftUI overlay point.
    private func swiftUIPoint(fromScreenPoint screenPoint: CGPoint) -> CGPoint? {
        guard let rect = overlayController.convertScreenRectToSwiftUIRect(
            CGRect(origin: screenPoint, size: CGSize(width: 1, height: 1))
        ) else {
            return nil
        }
        return rect.origin
    }
}
