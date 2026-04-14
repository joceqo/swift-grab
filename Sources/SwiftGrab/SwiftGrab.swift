import Foundation

public enum SwiftGrab {
    public static func start(mode: GrabMode = .appLocal) {
        Task { @MainActor in
            SwiftGrabManager.shared.start(mode: mode)
        }
    }

    public static func stop() {
        Task { @MainActor in
            SwiftGrabManager.shared.stop()
        }
    }

    public static func onPayloadCaptured(_ handler: @MainActor @escaping (GrabPayload) -> Void) {
        Task { @MainActor in
            SwiftGrabManager.shared.onPayloadCaptured(handler)
        }
    }
}
