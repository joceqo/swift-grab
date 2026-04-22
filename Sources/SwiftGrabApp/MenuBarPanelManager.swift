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
    private var clickOutsideLocalMonitor: Any?
    private let panelWidth: CGFloat = 260

    override init() {
        super.init()
        createStatusItem()
    }

    func cleanup() {
        removeClickOutsideMonitor()
    }

    // MARK: - Status Item

    private func createStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        guard let button = statusItem?.button else { return }

        let config = NSImage.SymbolConfiguration(pointSize: 14, weight: .semibold)
        let image = NSImage(systemSymbolName: "scope", accessibilityDescription: "SwiftGrab")?
            .withSymbolConfiguration(config)
        image?.isTemplate = true
        button.image = image
        button.target = self
        button.action = #selector(statusItemClicked)
    }

    @objc private func statusItemClicked() {
        if SwiftGrabManager.shared.currentMode != nil {
            SwiftGrabManager.shared.stop()
            showPanel()
            return
        }
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

    private func makePanelView() -> MenuBarPanelView {
        MenuBarPanelView(onStartInspector: { [weak self] in
            self?.hidePanel()
        })
    }

    private func createPanel() {
        let hostingView = NSHostingView(rootView: makePanelView())

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
        clickOutsideLocalMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            Task { @MainActor in
                guard let self else { return }
                // Skip status item clicks — statusItemClicked handles toggling.
                if event.window === self.panel || event.window === self.statusItem?.button?.window {
                    return
                }
                self.hidePanel()
            }
            return event
        }
    }

    private func removeClickOutsideMonitor() {
        if let monitor = clickOutsideMonitor {
            NSEvent.removeMonitor(monitor)
            clickOutsideMonitor = nil
        }
        if let monitor = clickOutsideLocalMonitor {
            NSEvent.removeMonitor(monitor)
            clickOutsideLocalMonitor = nil
        }
    }
}
