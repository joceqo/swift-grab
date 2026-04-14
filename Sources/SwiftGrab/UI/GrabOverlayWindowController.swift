import AppKit
import SwiftUI

@MainActor
final class GrabOverlayWindowController {
    private weak var panel: NSPanel?

    func present(with manager: SwiftGrabManager) {
        guard panel == nil else { return }
        guard let screen = NSScreen.main else { return }

        let panel = NSPanel(
            contentRect: screen.frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.level = .statusBar
        panel.ignoresMouseEvents = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.isMovableByWindowBackground = false
        panel.hidesOnDeactivate = false

        let hosting = NSHostingView(rootView: GrabOverlayView(manager: manager))
        hosting.frame = panel.contentView?.bounds ?? .zero
        hosting.autoresizingMask = [.width, .height]
        panel.contentView = hosting
        panel.orderFrontRegardless()
        self.panel = panel
    }

    func dismiss() {
        panel?.orderOut(nil)
        panel = nil
    }

    /// Convert an AppKit window-local point (from NSEvent.locationInWindow) to screen coordinates.
    func convertWindowPointToScreen(_ windowPoint: CGPoint) -> CGPoint? {
        guard let panel else { return nil }
        return CoordinateMapper.screenPoint(
            fromWindowPoint: windowPoint,
            overlayScreenFrame: panel.frame
        )
    }

    /// Convert a SwiftUI gesture point (origin top-left) to AppKit screen coordinates.
    func convertSwiftUIPointToScreen(_ swiftUIPoint: CGPoint) -> CGPoint? {
        guard let panel else { return nil }
        return CoordinateMapper.screenPoint(
            fromSwiftUIPoint: swiftUIPoint,
            overlayScreenFrame: panel.frame
        )
    }

    /// Convert an AppKit screen rect to SwiftUI overlay coordinates for display.
    func convertScreenRectToSwiftUIRect(_ screenRect: CGRect) -> CGRect? {
        guard let panel else { return nil }
        return CoordinateMapper.swiftUIRect(
            fromScreenRect: screenRect,
            overlayScreenFrame: panel.frame
        )
    }
}
