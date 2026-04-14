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
        screenshotPNGBase64: "abcd",
        errors: []
    )

    let json = try payload.toJSON(prettyPrinted: false)
    #expect(json.contains("\"mode\":\"appLocal\""))
    #expect(json.contains("\"windowTitle\":\"Main\""))
    #expect(json.contains("\"screenshotPNGBase64\":\"abcd\""))
}
