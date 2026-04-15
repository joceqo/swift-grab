import AppKit
import SwiftUI

@MainActor
final class GrabOverlayWindowController {
    private weak var panel: GrabPanel?

    func present(with manager: SwiftGrabManager) {
        guard panel == nil else { return }
        guard let screen = NSScreen.main else { return }

        let panel = GrabPanel(
            contentRect: screen.frame,
            styleMask: [.borderless],
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
        panel.becomesKeyOnlyIfNeeded = true

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

    /// Enable or disable keyboard input (post-capture TextField needs key window status).
    func setAcceptsKeyInput(_ accepts: Bool) {
        guard let panel else { return }
        panel.acceptsKeyInput = accepts
        if accepts {
            panel.makeKey()
        }
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

// MARK: - Custom panel with togglable key window support

private class GrabPanel: NSPanel {
    /// When true, the panel can become key window (needed for TextField input).
    /// When false, the panel stays non-activating (selection mode).
    var acceptsKeyInput = false

    override var canBecomeKey: Bool { acceptsKeyInput }
}
