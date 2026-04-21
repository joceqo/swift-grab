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

@Test
func richAccessibilityAttributesIncludedInJSON() throws {
    let payload = GrabPayload(
        mode: .global,
        screenFrame: .init(x: 0, y: 0, width: 100, height: 50),
        cursorPoint: .init(x: 50, y: 25),
        metadata: .init(
            accessibilityRole: "AXButton",
            accessibilitySubrole: "AXCloseButton",
            accessibilityIdentifier: "save-button",
            accessibilityTitle: "Save",
            accessibilityValue: "unsaved",
            accessibilityHelp: "Persist the document",
            accessibilityURL: "https://example.com/docs",
            accessibilitySelectedText: "Hello world"
        )
    )

    let json = try payload.toJSON(prettyPrinted: false)
    #expect(json.contains("\"accessibilitySubrole\":\"AXCloseButton\""))
    #expect(json.contains("\"accessibilityIdentifier\":\"save-button\""))
    #expect(json.contains("\"accessibilityHelp\":\"Persist the document\""))
    #expect(json.contains("\"accessibilityURL\":\"https:\\/\\/example.com\\/docs\""))
    #expect(json.contains("\"accessibilitySelectedText\":\"Hello world\""))
}

@Test
func optionalAccessibilityFieldsOmittedWhenNil() throws {
    let payload = GrabPayload(
        mode: .appLocal,
        screenFrame: .init(x: 0, y: 0, width: 10, height: 10),
        cursorPoint: .init(x: 5, y: 5),
        metadata: .init(accessibilityRole: "AXButton")
    )

    let json = try payload.toJSON(prettyPrinted: false)
    #expect(!json.contains("accessibilitySubrole"))
    #expect(!json.contains("accessibilityIdentifier"))
    #expect(!json.contains("accessibilityHelp"))
    #expect(!json.contains("accessibilityURL"))
    #expect(!json.contains("accessibilitySelectedText"))
}

@Test
func globalModeEncodesCorrectly() throws {
    let payload = GrabPayload(
        mode: .global,
        screenFrame: .init(x: 0, y: 0, width: 10, height: 10),
        cursorPoint: .init(x: 5, y: 5),
        metadata: .init()
    )
    let json = try payload.toJSON(prettyPrinted: false)
    #expect(json.contains("\"mode\":\"global\""))
}

@Test
func errorsArrayIsEncoded() throws {
    let payload = GrabPayload(
        mode: .appLocal,
        screenFrame: .init(x: 0, y: 0, width: 10, height: 10),
        cursorPoint: .init(x: 5, y: 5),
        metadata: .init(),
        errors: ["screen recording denied", "ax lookup failed"]
    )
    let json = try payload.toJSON(prettyPrinted: false)
    #expect(json.contains("\"errors\":[\"screen recording denied\",\"ax lookup failed\"]"))
}
