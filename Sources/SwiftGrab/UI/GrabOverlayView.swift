import SwiftUI

struct GrabOverlayView: View {
    @ObservedObject var manager: SwiftGrabManager

    var body: some View {
        ZStack(alignment: .topTrailing) {
            if let hoverRect = manager.hoverFrame {
                Rectangle()
                    .stroke(Color.blue, lineWidth: 2)
                    .background(Color.blue.opacity(0.12))
                    .frame(width: hoverRect.width, height: hoverRect.height)
                    .position(x: hoverRect.midX, y: hoverRect.midY)
            }

            GrabToolbarView(
                note: $manager.userNote,
                onSelectElement: { manager.setSelectionTool(.element) },
                onSelectRegion: { manager.setSelectionTool(.region) },
                onCancel: { manager.stop() },
                onCopyPayload: { manager.copyLastPayloadToClipboard() }
            )
            .padding(20)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .onTapGesture { location in
            manager.handleClick(atOverlayPoint: location)
        }
    }
}
