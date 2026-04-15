import Testing
@testable import SwiftGrab

@Test
func payloadEncodesToJSON() throws {
    let payload = GrabPayload(
        mode: .appLocal,
        screenFrame: .init(x: 10, y: 20, width: 300, height: 140),
        cursorPoint: .init(x: 30, y: 40),
        userNote: "Button is unresponsive",
        metadata: .init(
            appBundleIdentifier: "com.example.app",
            processIdentifier: 123,
            windowTitle: "Main",
            viewType: "NSButton"
        ),
        errors: []
    )

    let json = try payload.toJSON(prettyPrinted: false)
    #expect(json.contains("\"mode\":\"appLocal\""))
    #expect(json.contains("\"windowTitle\":\"Main\""))
    #expect(!json.contains("screenshot"))
}

@Test
func userNoteIncludedInJSON() throws {
    let payload = GrabPayload(
        mode: .appLocal,
        screenFrame: .init(x: 0, y: 0, width: 100, height: 50),
        cursorPoint: .init(x: 50, y: 25),
        userNote: "button not aligned",
        metadata: .init()
    )

    let json = try payload.toJSON(prettyPrinted: false)
    #expect(json.contains("\"userNote\":\"button not aligned\""))
}

@Test
func userNoteOmittedWhenNil() throws {
    let payload = GrabPayload(
        mode: .appLocal,
        screenFrame: .init(x: 0, y: 0, width: 100, height: 50),
        cursorPoint: .init(x: 50, y: 25),
        userNote: nil,
        metadata: .init()
    )

    let json = try payload.toJSON(prettyPrinted: false)
    #expect(!json.contains("userNote"))
}

@Test
func elementDescriptionIncludedInJSON() throws {
    let payload = GrabPayload(
        mode: .appLocal,
        screenFrame: .init(x: 0, y: 0, width: 100, height: 50),
        cursorPoint: .init(x: 50, y: 25),
        metadata: .init(
            accessibilityRole: "AXButton",
            elementDescription: "Button \"Save\""
        )
    )

    let json = try payload.toJSON(prettyPrinted: false)
    #expect(json.contains("\"accessibilityRole\":\"AXButton\""))
    #expect(json.contains("\"elementDescription\":\"Button \\\"Save\\\"\""))
}

@Test
func viewHierarchyIncludedInJSON() throws {
    let payload = GrabPayload(
        mode: .appLocal,
        screenFrame: .init(x: 0, y: 0, width: 100, height: 50),
        cursorPoint: .init(x: 50, y: 25),
        metadata: .init(
            viewHierarchy: [
                "Button \"Save\"",
                "NSStackView",
                "NSVisualEffectView",
                "NSView",
                "NSWindow \"Main\""
            ]
        )
    )

    let json = try payload.toJSON(prettyPrinted: false)
    #expect(json.contains("\"viewHierarchy\""))
    #expect(json.contains("\"Button \\\"Save\\\"\""))
    #expect(json.contains("\"NSStackView\""))
    #expect(json.contains("\"NSWindow \\\"Main\\\"\""))
}
