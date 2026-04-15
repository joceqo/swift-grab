import AppKit
import SwiftGrab

print("[SwiftGrabApp] Starting...")

let app = NSApplication.shared
print("[SwiftGrabApp] setActivationPolicy")
app.setActivationPolicy(.accessory)

let delegate = SwiftGrabAppDelegate()
app.delegate = delegate
print("[SwiftGrabApp] finishLaunching")
app.finishLaunching()

print("[SwiftGrabApp] entering run loop")
app.run()
print("[SwiftGrabApp] run loop exited (should not happen)")
