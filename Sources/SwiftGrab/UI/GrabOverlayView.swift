import SwiftUI

struct GrabOverlayView: View {
    @ObservedObject var manager: SwiftGrabManager

    var body: some View {
        ZStack {
            // Layer 1: Full-screen gesture target. Stays active post-capture so a
            // new click replaces the current capture without needing to hit Retake.
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

        if !manager.isRegionToolSelected,
           manager.lastCaptureFrame == nil,
           let cursorPoint = manager.hoverCursorPoint,
           let info = manager.hoverContextInfo {
            tagBadge(info)
                .position(x: cursorPoint.x + 110, y: cursorPoint.y + 20)
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
        if manager.lastCaptureFrame != nil {
            VStack {
                Spacer()
                postCapturePanel()
                    .background(controlsRectReporter)
                    .padding(.bottom, 24)
            }
            .frame(maxWidth: .infinity)
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
                .background(controlsRectReporter)
                .padding(.bottom, 24)
            }
            .frame(maxWidth: .infinity)
        }
    }

    private var controlsRectReporter: some View {
        GeometryReader { proxy in
            Color.clear
                .onAppear { manager.controlsSwiftUIRect = proxy.frame(in: .global) }
                .onChange(of: proxy.frame(in: .global)) { newValue in
                    manager.controlsSwiftUIRect = newValue
                }
        }
    }

    // MARK: - Post-capture panel

    private func postCapturePanel() -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // App + element description
            VStack(alignment: .leading, spacing: 2) {
                if let app = manager.lastCapturedAppName {
                    Text(app)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Color.accentColor)
                        .lineLimit(1)
                }
                if let desc = manager.lastElementDescription {
                    Text(desc)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.black)
                        .lineLimit(2)
                        .truncationMode(.middle)
                }
            }
            .frame(maxWidth: 360, alignment: .leading)
            .padding(.horizontal, 12)
            .padding(.top, 10)
            .padding(.bottom, 8)

            // Divider
            Rectangle()
                .fill(Color(white: 0.93))
                .frame(height: 1)

            // Note input + actions
            VStack(alignment: .leading, spacing: 8) {
                TextField("Add context...", text: $manager.userNote)
                    .font(.system(size: 12))
                    .textFieldStyle(.plain)
                    .frame(minWidth: 300)

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
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
        }
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .shadow(color: .black.opacity(0.12), radius: 8, y: 4)
        .shadow(color: .black.opacity(0.04), radius: 1, y: 1)
        .fixedSize()
        .environment(\.colorScheme, .light)
    }
}
