import SwiftUI

@main
struct SwiftGrabApp: App {
    @NSApplicationDelegateAdaptor(SwiftGrabAppDelegate.self) var appDelegate

    var body: some Scene {
        // App lives entirely in the menu bar panel. This empty Settings scene
        // satisfies SwiftUI's requirement for at least one scene.
        Settings {
            EmptyView()
        }
    }
}
