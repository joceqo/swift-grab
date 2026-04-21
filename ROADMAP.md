# Roadmap

Short list of things that would make SwiftGrab more useful. Ordered by payoff.

## Near-term

### Optional screenshot attachment
Attach a PNG of the captured element frame to the payload. Was wired earlier; now bring it back as an opt-in since most AI payloads are text-only.

- New setting in the menu bar panel: **Capture screenshot** (toggle, default off).
- When on, after AX capture, grab the bitmap for `screenFrame` via `ScreenCaptureKit`.
- Emit two modes on the payload:
  - `screenshotPath`: absolute path to a PNG written under `~/Library/Caches/SwiftGrab/captures/<timestamp>.png`.
  - `screenshotBase64`: `data:image/png;base64,…` inline.
- User picks `Path` / `Base64` in the same settings row. Both are written into `GrabPayload`; JSON shows whichever the user picked.
- Requires Screen Recording permission — surface a permission row in the menu bar panel, same UX as Accessibility.
- Write to `GrabPayload.screenshotPath: String?` and `screenshotBase64: String?` — nil when toggle is off or permission denied, so existing consumers stay compatible.

### OCR fallback for shallow AX trees
When the drilled AX element is just `AXGroup` / `AXUnknown` with no title/value (Electron, Flutter, Metal apps), run Vision `VNRecognizeTextRequest` on the captured bitmap. Add `metadata.ocrText: String?`. Cheap win when the app has real visible text but no AX labels.

### Framework detection
Walk the captured element's ancestors looking for `AXWebArea` → tag payload `uiFramework: "Web/Electron"`. Detect `NSHostingView` subrole → `SwiftUI`. Otherwise `AppKit` / `Unknown`. One-line metadata field, helps AI agents tailor suggestions.

## Mid-term

### Sibling context
Collect peer elements of the captured node (parent's other children): role + title + identifier. Encoded as `metadata.siblings: [String]`. Gives agents the surrounding UI without needing hierarchy navigation.

### History panel
Store the last N captures in the menu bar panel with a re-copy button. Useful when iterating with an agent.

### Region mode polish
Currently region captures have empty metadata. When region mode fires, also gather AX elements intersecting the region and attach them as `metadata.regionElements: [HierarchyNode]`.

## Long-term

### Diff-aware re-capture
Re-inspect the same target after a code change, diff the two payloads, emit a change log. Useful for visual regression workflows.

### Plugin hooks
Expose a `SwiftGrabPlugin` protocol so consumers can enrich the payload (e.g. add git blame for the source file, link to the Figma node, post to Slack). Similar to `react-grab`'s plugin config.

### Cross-device capture
Send a captured payload to a remote agent over a signed local URL scheme so a machine running the IDE can receive from a separate inspection machine. Edge case, but requested by people running their editor in a VM.
