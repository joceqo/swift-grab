import SwiftUI

struct GrabToolbarView: View {
    @Binding var note: String
    var onSelectElement: () -> Void
    var onSelectRegion: () -> Void
    var onCancel: () -> Void
    var onCopyPayload: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("SwiftGrab")
                .font(.headline)
            HStack {
                Button("Select Element", action: onSelectElement)
                Button("Select Region", action: onSelectRegion)
            }
            HStack {
                Button("Cancel", role: .cancel, action: onCancel)
                Button("Copy Payload", action: onCopyPayload)
            }
            TextField("What should AI fix?", text: $note)
                .textFieldStyle(.roundedBorder)
                .frame(width: 280)
        }
        .padding(12)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color.secondary.opacity(0.25), lineWidth: 1)
        )
        .shadow(radius: 10)
    }
}
