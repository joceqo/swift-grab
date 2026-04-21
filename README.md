# SwiftGrab

`SwiftGrab` is a macOS Swift package that provides an app-local inspector flow similar to `react-grab` for native apps.

## Features

- Toggle inspect mode with `Cmd+Option+I`
- Floating non-activating toolbar (`Select Element`, `Select Region`, `Cancel`, `Copy Payload`)
- Hover highlight and click-to-capture
- Drag-to-select region capture
- AI-ready payload with screenshot + metadata + user note
- SwiftUI modifier for drop-in integration

## Install

1. In Xcode: **File > Add Package Dependencies...**
2. Add this package URL (replace with your repo URL once published).
3. Add product `SwiftGrab` to your macOS app target.

Local development in this repo:

```bash
swift build
swift run SwiftGrabDemo
```

## Running the Menu Bar App

Use the provided script — it builds a signed `.app` bundle so the Accessibility grant survives rebuilds:

```bash
./scripts/run.sh
```

Then grant Accessibility to `SwiftGrab.app` in **System Settings → Privacy & Security → Accessibility**.

**Do not use `swift run SwiftGrabApp`.** The CLI binary path changes on every rebuild, and macOS TCC treats each rebuilt binary as a new app — the grant won't stick.

## Quick Start

```swift
import SwiftUI
import SwiftGrab

struct ContentView: View {
    var body: some View {
        MainScreen()
            .swiftGrab(enabled: true, onCapture: { payload in
                print((try? payload.toJSON(prettyPrinted: true)) ?? "")
            })
    }
}
```

You can also control it directly:

```swift
SwiftGrab.onPayloadCaptured { payload in
    print(try? payload.toJSON())
}
SwiftGrab.start(mode: .appLocal)
// ...
SwiftGrab.stop()
```

## Payload Example

```json
{
  "mode": "appLocal",
  "screenFrame": { "x": 100, "y": 120, "width": 260, "height": 44 },
  "cursorPoint": { "x": 180, "y": 140 },
  "userNote": "Button is broken when clicked",
  "metadata": {
    "appBundleIdentifier": "com.example.MyApp",
    "processIdentifier": 12345,
    "windowTitle": "Main Window",
    "viewType": "NSButton",
    "accessibilityTitle": "Submit",
    "accessibilityValue": null,
    "timestamp": "2026-04-14T16:00:00Z"
  },
  "screenshotPNGBase64": "<base64 PNG>",
  "errors": []
}
```

## How To Send Payload To AI

1. Capture with `Cmd+Option+I`.
2. Add user note in toolbar (`What should AI fix?`).
3. Click target element or region.
4. Use `Copy Payload` and paste JSON into your AI prompt.
5. Ask for a concrete fix using this context and screenshot data.

## App-local V1 Limitations

- Inspects only the host app window hierarchy.
- Inspects only one app-local context (no cross-app AX hit testing yet).
- If Screen Recording is denied, payload is still emitted with metadata and an `errors` entry.

## V2 Notes

- Screenshot capture uses `ScreenCaptureKit`.
- Toolbar includes `Grant Screen Access` to trigger screen recording permission prompt.
- Region mode captures drag selection rectangle instead of fixed box.
