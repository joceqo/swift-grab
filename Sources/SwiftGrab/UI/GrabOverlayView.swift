import SwiftUI

struct GrabOverlayView: View {
    @ObservedObject var manager: SwiftGrabManager

    private var isSelecting: Bool {
        manager.lastCaptureFrame == nil
    }

    var body: some View {
        ZStack {
            // Layer 1: Full-screen gesture target — only during selection.
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

            // Layer 2: Decorations (non-interactive)
            decorationsLayer
                .allowsHitTesting(false)

            // Layer 3: Interactive controls
            controlsLayer
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Decorations

    @ViewBuilder
    private var decorationsLayer: some View {
        if let hoverRect = manager.hoverFrame {
            // Highlight rectangle
            Rectangle()
                .stroke(Color.accentColor, lineWidth: 2)
                .background(Color.accentColor.opacity(0.08))
                .frame(width: hoverRect.width, height: hoverRect.height)
                .position(x: hoverRect.midX, y: hoverRect.midY)

            // Element tag badge (element mode)
            if !manager.isRegionToolSelected, let info = manager.hoverInfo {
                tagBadge(info)
                    .position(x: hoverRect.midX, y: hoverRect.maxY + 14)
            }

            // Region size (region mode)
            if manager.isRegionToolSelected, let sizeText = manager.regionSizeText {
                tagBadge(sizeText)
                    .position(x: hoverRect.midX, y: hoverRect.minY - 14)
            }
        }
    }

    private func tagBadge(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(.black)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(.white)
            .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
            .shadow(color: .black.opacity(0.12), radius: 4, y: 2)
            .shadow(color: .black.opacity(0.04), radius: 1, y: 1)
    }

    // MARK: - Controls

    @ViewBuilder
    private var controlsLayer: some View {
        if let capturedFrame = manager.lastCaptureFrame {
            postCapturePanel(at: capturedFrame)
        } else {
            VStack {
                Spacer()
                GrabToolbarView(
                    isRegionMode: manager.isRegionToolSelected,
                    statusText: manager.statusText,
                    onSelectElement: { manager.setSelectionTool(.element) },
                    onSelectRegion: { manager.setSelectionTool(.region) },
                    onCancel: { manager.stop() }
                )
                .padding(.bottom, 24)
            }
            .frame(maxWidth: .infinity)
        }
    }

    // MARK: - Post-capture panel

    private func postCapturePanel(at capturedFrame: CGRect) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // Tag + element description
            if let desc = manager.lastElementDescription {
                HStack(spacing: 6) {
                    Text(desc)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.black)
                        .lineLimit(1)
                }
                .padding(.horizontal, 10)
                .padding(.top, 8)
                .padding(.bottom, 6)
            }

            // Divider
            Rectangle()
                .fill(Color(white: 0.93))
                .frame(height: 1)

            // Note input + actions
            VStack(alignment: .leading, spacing: 8) {
                TextField("Add context...", text: $manager.userNote)
                    .font(.system(size: 12))
                    .textFieldStyle(.plain)
                    .frame(minWidth: 240)

                HStack(spacing: 6) {
                    Button(action: { manager.copyLastPayloadAndClose() }) {
                        Text("Copy & Close")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(.black)
                            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .keyboardShortcut(.return, modifiers: [])

                    Button(action: { manager.retakeSelection() }) {
                        Text("Retake")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(Color(white: 0.4))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Color(white: 0.95))
                            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
        }
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .shadow(color: .black.opacity(0.12), radius: 8, y: 4)
        .shadow(color: .black.opacity(0.04), radius: 1, y: 1)
        .position(x: capturedFrame.midX, y: capturedFrame.maxY + 48)
    }
}
