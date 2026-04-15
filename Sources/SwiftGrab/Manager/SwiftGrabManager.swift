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

    // Hierarchy traversal state
    private var currentHierarchy: [HierarchyNode] = []
    private var hierarchyIndex: Int = 0
    private var lastInspection: AppLocalInspectionResult?

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
        currentHierarchy = []
        hierarchyIndex = 0
        lastInspection = nil
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
        currentHierarchy = []
        hierarchyIndex = 0
        lastInspection = nil
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
            captureAtCurrentLevel(screenPoint: screenPoint)
        case .region:
            handleRegionPointClick(at: screenPoint)
        }
    }

    func handleRegionDragChanged(atSwiftUIPoint point: CGPoint) {
        guard selectionTool == .region else { return }
        if regionDragStart == nil {
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

    // MARK: - Hierarchy traversal (arrow keys)

    func navigateUp() {
        guard selectionTool == .element, !currentHierarchy.isEmpty else { return }
        guard lastCaptureFrame == nil else { return }
        if hierarchyIndex < currentHierarchy.count - 1 {
            hierarchyIndex += 1
            displayHierarchyLevel()
        }
    }

    func navigateDown() {
        guard selectionTool == .element, !currentHierarchy.isEmpty else { return }
        guard lastCaptureFrame == nil else { return }
        if hierarchyIndex > 0 {
            hierarchyIndex -= 1
            displayHierarchyLevel()
        }
    }

    private func displayHierarchyLevel() {
        guard hierarchyIndex < currentHierarchy.count else { return }
        let node = currentHierarchy[hierarchyIndex]
        hoverFrame = overlayController.convertScreenRectToSwiftUIRect(node.screenFrame)
        hoverInfo = "\(node.description)  (\(hierarchyIndex + 1)/\(currentHierarchy.count))"
        statusText = "↑↓ Navigate hierarchy • Click to capture"
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
        currentHierarchy = []
        hierarchyIndex = 0
        lastInspection = nil
        statusText = selectionTool == .element
            ? "Element mode: click a target to capture."
            : "Region mode: click first corner, then opposite corner."
    }

    // MARK: - Mouse / key tracking (AppKit events)

    private func installMouseTracking() {
        trackingMonitor = NSEvent.addLocalMonitorForEvents(matching: [.mouseMoved]) { [weak self] event in
            Task { @MainActor in
                guard let self else { return }
                guard let screenPoint = self.overlayController.convertWindowPointToScreen(event.locationInWindow) else { return }
                self.updateHover(for: screenPoint)
            }
            return event
        }
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { [weak self] event in
            switch event.keyCode {
            case 53: // ESC
                Task { @MainActor in
                    guard let self else { return }
                    if self.hierarchyIndex > 0 {
                        // Reset traversal back to deepest
                        self.hierarchyIndex = 0
                        self.displayHierarchyLevel()
                        self.statusText = "Element mode: click a target to capture."
                    } else {
                        self.stop()
                    }
                }
                return nil
            case 126: // Arrow Up
                Task { @MainActor in self?.navigateUp() }
                return nil
            case 125: // Arrow Down
                Task { @MainActor in self?.navigateDown() }
                return nil
            default:
                return event
            }
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
        guard lastCaptureFrame == nil else { return }
        // Freeze hover while user is traversing the hierarchy with arrow keys
        guard hierarchyIndex == 0 else { return }
        switch selectionTool {
        case .element:
            let inspection = AppLocalInspector.inspect(at: screenPoint)
            lastInspection = inspection
            currentHierarchy = inspection.hierarchyNodes
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

    // MARK: - Capture

    private func captureAtCurrentLevel(screenPoint: CGPoint) {
        // Use the stored hierarchy level if available
        let frame: CGRect
        var metadata: GrabPayload.GrabMetadata

        if !currentHierarchy.isEmpty, let inspection = lastInspection {
            let node = currentHierarchy[hierarchyIndex]
            frame = node.screenFrame.isEmpty ? inspection.screenFrame : node.screenFrame
            metadata = inspection.metadata
            metadata.elementDescription = node.description
        } else {
            let inspection = AppLocalInspector.inspect(at: screenPoint)
            frame = inspection.screenFrame
            metadata = inspection.metadata
        }

        let payload = GrabPayload(
            mode: .appLocal,
            screenFrame: frame,
            cursorPoint: screenPoint,
            userNote: userNote.isEmpty ? nil : userNote,
            metadata: metadata
        )
        lastPayload = payload
        lastCaptureFrame = overlayController.convertScreenRectToSwiftUIRect(frame)
        hoverInfo = nil
        currentHierarchy = []
        hierarchyIndex = 0
        lastInspection = nil
        overlayController.setAcceptsKeyInput(true)
        statusText = "Captured element. Copy payload or pick again."
        captureHandler?(payload)
    }

    private func capture(regionRect: CGRect, cursorPoint: CGPoint) {
        let metadata = GrabPayload.GrabMetadata(
            appBundleIdentifier: Bundle.main.bundleIdentifier,
            processIdentifier: ProcessInfo.processInfo.processIdentifier
        )
        let payload = GrabPayload(
            mode: .appLocal,
            screenFrame: regionRect,
            cursorPoint: cursorPoint,
            userNote: userNote.isEmpty ? nil : userNote,
            metadata: metadata
        )
        lastPayload = payload
        lastCaptureFrame = overlayController.convertScreenRectToSwiftUIRect(regionRect)
        hoverInfo = nil
        overlayController.setAcceptsKeyInput(true)
        statusText = "Captured region. Copy payload or pick again."
        captureHandler?(payload)
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

    private func swiftUIPoint(fromScreenPoint screenPoint: CGPoint) -> CGPoint? {
        guard let rect = overlayController.convertScreenRectToSwiftUIRect(
            CGRect(origin: screenPoint, size: CGSize(width: 1, height: 1))
        ) else {
            return nil
        }
        return rect.origin
    }
}
