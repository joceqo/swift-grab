import SwiftUI

struct GrabOverlayView: View {
    @ObservedObject var manager: SwiftGrabManager

    var body: some View {
        ZStack(alignment: .topLeading) {
            // Hover highlight
            if let hoverRect = manager.hoverFrame {
                Rectangle()
                    .stroke(Color.blue, lineWidth: 2)
                    .background(Color.blue.opacity(0.12))
                    .frame(width: hoverRect.width, height: hoverRect.height)
                    .position(x: hoverRect.midX, y: hoverRect.midY)

                // Element info tooltip (element mode only)
                if !manager.isRegionToolSelected, let info = manager.hoverInfo {
                    Text(info)
                        .font(.caption.monospaced())
                        .lineLimit(1)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .stroke(Color.blue.opacity(0.3), lineWidth: 1)
                        )
                        .position(x: hoverRect.midX, y: hoverRect.maxY + 14)
                }

                // Region size label
                if manager.isRegionToolSelected, let regionSizeText = manager.regionSizeText {
                    Text(regionSizeText)
                        .font(.caption.monospacedDigit())
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.regularMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                        .position(x: hoverRect.midX, y: hoverRect.minY - 14)
                }
            }

            // Post-capture panel
            if let capturedFrame = manager.lastCaptureFrame {
                VStack(alignment: .leading, spacing: 8) {
                    if let desc = manager.lastElementDescription {
                        Text(desc)
                            .font(.caption.monospaced())
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    TextField("Add a note for AI...", text: $manager.userNote)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 280)
                    HStack(spacing: 8) {
                        Button("Copy & Close") { manager.copyLastPayloadAndClose() }
                            .keyboardShortcut(.return, modifiers: [])
                        Button("Retake") { manager.retakeSelection() }
                    }
                }
                .padding(10)
                .background(.regularMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(Color.secondary.opacity(0.25), lineWidth: 1)
                )
                .position(x: capturedFrame.midX, y: capturedFrame.maxY + 50)
            }

            // Toolbar (hidden after capture)
            if manager.lastCaptureFrame == nil {
                GrabToolbarView(
                    permissionMessage: manager.permissionMessage,
                    statusText: manager.statusText,
                    onSelectElement: { manager.setSelectionTool(.element) },
                    onSelectRegion: { manager.setSelectionTool(.region) },
                    onCancel: { manager.stop() },
                    onRequestPermission: { manager.requestScreenRecordingPermission() }
                )
                .padding(16)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .onTapGesture { location in
            manager.handleClick(atSwiftUIPoint: location)
        }
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    manager.handleRegionDragChanged(atSwiftUIPoint: value.location)
                }
                .onEnded { value in
                    manager.handleRegionDragEnded(atSwiftUIPoint: value.location)
                }
        )
    }
}
