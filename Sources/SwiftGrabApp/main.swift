import AppKit
import SwiftGrab

let app = NSApplication.shared
app.setActivationPolicy(.accessory) // No dock icon — menu bar only
let delegate = SwiftGrabAppDelegate()
app.delegate = delegate
app.run()
