import AppKit
import SwiftUI

public struct SwiftGrabModifier: ViewModifier {
    let enabled: Bool
    let mode: GrabMode
    let onCapture: @MainActor (GrabPayload) -> Void

    public func body(content: Content) -> some View {
        content
            .background(
                GrabHotkeyBridge(
                    enabled: enabled,
                    mode: mode,
                    onCapture: onCapture
                )
                .frame(width: 0, height: 0)
            )
    }
}

public extension View {
    func swiftGrab(
        enabled: Bool,
        mode: GrabMode = .appLocal,
        onCapture: @MainActor @escaping (GrabPayload) -> Void
    ) -> some View {
        modifier(SwiftGrabModifier(enabled: enabled, mode: mode, onCapture: onCapture))
    }
}

private struct GrabHotkeyBridge: NSViewRepresentable {
    let enabled: Bool
    let mode: GrabMode
    let onCapture: @MainActor (GrabPayload) -> Void

    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)
        context.coordinator.install(enabled: enabled, mode: mode, onCapture: onCapture)
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        context.coordinator.install(enabled: enabled, mode: mode, onCapture: onCapture)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    @MainActor
    final class Coordinator {
        private var monitor: Any?

        func install(enabled: Bool, mode: GrabMode, onCapture: @MainActor @escaping (GrabPayload) -> Void) {
            SwiftGrabManager.shared.onPayloadCaptured(onCapture)
            if !enabled {
                SwiftGrabManager.shared.stop()
                removeMonitor()
                return
            }

            guard monitor == nil else { return }
            monitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { event in
                guard event.modifierFlags.contains([.command, .option]),
                      event.charactersIgnoringModifiers?.lowercased() == "i"
                else { return event }

                Task { @MainActor in
                    if SwiftGrabManager.shared.currentMode == nil {
                        SwiftGrabManager.shared.start(mode: mode)
                    } else {
                        SwiftGrabManager.shared.stop()
                    }
                }
                return nil
            }
        }

        private func removeMonitor() {
            if let monitor {
                NSEvent.removeMonitor(monitor)
            }
            monitor = nil
        }
    }
}
