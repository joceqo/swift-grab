import SwiftUI
import AppKit
import SwiftGrab

struct SwiftGrabDemoApp: App {
    @State private var payloadText = "Press Cmd+Option+I to toggle SwiftGrab."

    init() {
        NSApplication.shared.setActivationPolicy(.regular)
        NSApplication.shared.activate(ignoringOtherApps: true)
    }

    var body: some Scene {
        WindowGroup {
            VStack(alignment: .leading, spacing: 14) {
                Text("SwiftGrab Demo")
                    .font(.title2.bold())
                Text("Try selecting a button or region in this app.")
                    .foregroundStyle(.secondary)
                Button("Sample Action") {
                    payloadText = "Clicked sample action."
                }
                ScrollView {
                    Text(payloadText)
                        .font(.system(.body, design: .monospaced))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(height: 220)
                .padding(8)
                .background(Color.gray.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .padding(24)
            .frame(minWidth: 560, minHeight: 380)
            .swiftGrab(enabled: true, onCapture: { payload in
                payloadText = (try? payload.toJSON(prettyPrinted: true)) ?? "Failed to encode payload."
            })
        }
    }
}

SwiftGrabDemoApp.main()
