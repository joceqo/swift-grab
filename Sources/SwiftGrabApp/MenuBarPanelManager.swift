import AppKit
import SwiftUI
import SwiftGrab

/// Custom NSPanel that can become key even with nonactivatingPanel style.
private class KeyablePanel: NSPanel {
    override var canBecomeKey: Bool { true }
}

@MainActor
final class MenuBarPanelManager: NSObject {
    private var statusItem: NSStatusItem?
    private var panel: KeyablePanel?
    private var clickOutsideMonitor: Any?
    private let panelWidth: CGFloat = 260

    override init() {
        super.init()
        createStatusItem()
    }

    func cleanup() {
        if let monitor = clickOutsideMonitor {
            NSEvent.removeMonitor(monitor)
            clickOutsideMonitor = nil
        }
    }

    // MARK: - Status Item

    private func createStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        guard let button = statusItem?.button else { return }

        button.image = NSImage(systemSymbolName: "scope", accessibilityDescription: "SwiftGrab")
        button.target = self
        button.action = #selector(statusItemClicked)
    }

    @objc private func statusItemClicked() {
        if let panel, panel.isVisible {
            hidePanel()
        } else {
            showPanel()
        }
    }

    // MARK: - Panel

    func showPanel() {
        if panel == nil { createPanel() }
        positionPanelBelowStatusItem()
        panel?.makeKeyAndOrderFront(nil)
        panel?.orderFrontRegardless()
        installClickOutsideMonitor()
    }

    func showPanelOnLaunch() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            self.showPanel()
        }
    }

    func hidePanel() {
        panel?.orderOut(nil)
        removeClickOutsideMonitor()
    }

    func refreshPanel() {
        // Rebuild the panel content to reflect current state
        guard let panel else { return }
        let hostingView = NSHostingView(rootView: MenuBarPanelView())
        hostingView.frame = panel.contentView?.bounds ?? .zero
        hostingView.autoresizingMask = [.width, .height]
        panel.contentView = hostingView
    }

    private func createPanel() {
        let hostingView = NSHostingView(rootView: MenuBarPanelView())

        let p = KeyablePanel(
            contentRect: NSRect(x: 0, y: 0, width: panelWidth, height: 200),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        p.isFloatingPanel = true
        p.level = .floating
        p.isOpaque = false
        p.backgroundColor = .clear
        p.hasShadow = false
        p.hidesOnDeactivate = false
        p.isExcludedFromWindowsMenu = true
        p.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        p.isMovableByWindowBackground = false
        p.titleVisibility = .hidden
        p.titlebarAppearsTransparent = true

        hostingView.frame = p.contentView?.bounds ?? .zero
        hostingView.autoresizingMask = [.width, .height]
        p.contentView = hostingView
        panel = p
    }

    private func positionPanelBelowStatusItem() {
        guard let panel, let buttonWindow = statusItem?.button?.window else { return }
        let statusFrame = buttonWindow.frame
        let fittingSize = panel.contentView?.fittingSize ?? CGSize(width: panelWidth, height: 200)
        let x = statusFrame.midX - (panelWidth / 2)
        let y = statusFrame.minY - fittingSize.height - 4
        panel.setFrame(NSRect(x: x, y: y, width: panelWidth, height: fittingSize.height), display: true)
    }

    // MARK: - Click outside dismissal

    private func installClickOutsideMonitor() {
        removeClickOutsideMonitor()
        clickOutsideMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            Task { @MainActor in
                self?.hidePanel()
            }
        }
    }

    private func removeClickOutsideMonitor() {
        if let monitor = clickOutsideMonitor {
            NSEvent.removeMonitor(monitor)
            clickOutsideMonitor = nil
        }
    }
}
