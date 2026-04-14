# AGENTS.md

Project guidance for coding agents working in this repository.

## Project Scope

- Package name: `SwiftGrab`
- Platform: macOS (Swift + SwiftUI + AppKit)
- Primary goal: app-local inspector flow for AI-ready bug/debug payloads

## Where To Work

- Core library: `@Sources/SwiftGrab/`
- Demo app: `@Sources/SwiftGrabDemo/`
- Tests: `@Tests/SwiftGrabTests/`
- Package manifest: `@Package.swift`
- Docs: `@README.md`

## Guardrails

- Keep v1 app-local unless explicitly asked for global cross-app inspection.
- Prefer explicit naming and beginner-readable code.
- Do not introduce private APIs.
- Keep comments concise and only where behavior is non-obvious.
- Avoid unrelated refactors.

## Implementation Priorities

1. Reliable inspect UX (`Cmd+Option+I`, hover, click capture)
2. High-quality payload (`GrabPayload` + JSON export)
3. Resilience (partial payload with structured errors, no crashes)
4. Test coverage for encoding and coordinate utilities

## Quick Verify

- Run tests: `swift test`
- Run demo: `swift run SwiftGrabDemo`
