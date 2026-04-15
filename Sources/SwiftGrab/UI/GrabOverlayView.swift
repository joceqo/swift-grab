import SwiftUI

struct GrabOverlayView: View {
    @ObservedObject var manager: SwiftGrabManager

    private var isSelecting: Bool {
        manager.lastCaptureFrame == nil
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            // Layer 1: Full-screen gesture target — only during selection.
            // Removed when post-capture so TextField/buttons receive events.
            if isSelecting {
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture { location in
                        manager.handleClick(atSwiftUIPoint: location)
                    }
                    .gesture(
                        DragGesture(minimumDistance: 4)
                            .onChanged { value in
                                manager.handleRegionDragChanged(atSwiftUIPoint: value.location)
                            }
                            .onEnded { value in
                                manager.handleRegionDragEnded(atSwiftUIPoint: value.location)
                            }
                    )
            }

            // Layer 2: Decorations — hover highlight, tooltip, region size.
            // Non-interactive so clicks pass through to the gesture layer or controls.
            decorationsLayer
                .allowsHitTesting(false)

            // Layer 3: Interactive controls — toolbar or post-capture panel.
            controlsLayer
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Decorations (non-interactive)

    @ViewBuilder
    private var decorationsLayer: some View {
        if let hoverRect = manager.hoverFrame {
            // Blue highlight rectangle
            Rectangle()
                .stroke(Color.accentColor, lineWidth: 2)
                .background(Color.accentColor.opacity(0.10))
                .frame(width: hoverRect.width, height: hoverRect.height)
                .position(x: hoverRect.midX, y: hoverRect.midY)

            // Element tooltip (element mode only)
            if !manager.isRegionToolSelected, let info = manager.hoverInfo {
                Text(info)
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(.regularMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    .shadow(color: .black.opacity(0.15), radius: 4, y: 2)
                    .position(x: hoverRect.midX, y: hoverRect.maxY + 16)
            }

            // Region size label (region mode only)
            if manager.isRegionToolSelected, let sizeText = manager.regionSizeText {
                Text(sizeText)
                    .font(.caption.monospacedDigit())
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.regularMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    .position(x: hoverRect.midX, y: hoverRect.minY - 14)
            }
        }
    }

    // MARK: - Interactive controls

    @ViewBuilder
    private var controlsLayer: some View {
        if let capturedFrame = manager.lastCaptureFrame {
            postCapturePanel(at: capturedFrame)
        } else {
            VStack {
                GrabToolbarView(
                    isRegionMode: manager.isRegionToolSelected,
                    statusText: manager.statusText,
                    onSelectElement: { manager.setSelectionTool(.element) },
                    onSelectRegion: { manager.setSelectionTool(.region) },
                    onCancel: { manager.stop() }
                )
                .padding(.top, 16)
                Spacer()
            }
            .frame(maxWidth: .infinity)
        }
    }

    // MARK: - Post-capture panel

    private func postCapturePanel(at capturedFrame: CGRect) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            // Element description header
            if let desc = manager.lastElementDescription {
                HStack(spacing: 6) {
                    Image(systemName: "scope")
                        .foregroundStyle(.blue)
                        .font(.caption)
                    Text(desc)
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            // Note input
            VStack(alignment: .leading, spacing: 4) {
                Text("What should AI look at?")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                TextField("e.g. button not aligned, text truncated...", text: $manager.userNote)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 300)
            }

            // Actions
            HStack(spacing: 8) {
                Button(action: { manager.copyLastPayloadAndClose() }) {
                    Label("Copy & Close", systemImage: "doc.on.clipboard")
                }
                .keyboardShortcut(.return, modifiers: [])
                .buttonStyle(.borderedProminent)

                Button("Retake", action: { manager.retakeSelection() })
                    .buttonStyle(.bordered)
            }
        }
        .padding(12)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.12), radius: 8, y: 4)
        .position(x: capturedFrame.midX, y: capturedFrame.maxY + 60)
    }
}
