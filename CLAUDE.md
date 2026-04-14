# CLAUDE.md

Assistant context for this repository.

## Reference Map

- Start here: `@README.md`
- Package setup: `@Package.swift`
- Public API surface: `@Sources/SwiftGrab/SwiftGrab.swift`, `@Sources/SwiftGrab/SwiftGrabModifier.swift`
- Runtime manager: `@Sources/SwiftGrab/Manager/SwiftGrabManager.swift`
- Capture models: `@Sources/SwiftGrab/Models/GrabPayload.swift`
- Capture pipeline: `@Sources/SwiftGrab/Capture/`
- Overlay UI: `@Sources/SwiftGrab/UI/`
- Coordinate helpers: `@Sources/SwiftGrab/Utilities/CoordinateMapper.swift`
- Test suite: `@Tests/SwiftGrabTests/`
- Demo host app: `@Sources/SwiftGrabDemo/main.swift`

## Working Conventions

- Keep changes focused and minimal.
- Preserve app-local behavior by default.
- If capture fails, return partial payload with `errors`.
- Validate changes with `swift test` whenever possible.

## Current Milestone

v1: app-local inspector package with floating toolbar, selection, screenshot, metadata, and AI-ready JSON payload.
