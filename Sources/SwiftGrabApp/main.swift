import AppKit
import SwiftGrab

let app = NSApplication.shared
app.setActivationPolicy(.accessory)

let delegate = SwiftGrabAppDelegate()
app.delegate = delegate
app.finishLaunching()
app.run()
