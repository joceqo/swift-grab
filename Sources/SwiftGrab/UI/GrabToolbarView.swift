import SwiftUI

struct GrabToolbarView: View {
    var permissionMessage: String?
    var statusText: String
    var onSelectElement: () -> Void
    var onSelectRegion: () -> Void
    var onCancel: () -> Void
    var onRequestPermission: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Button("Pick Element", action: onSelectElement)
                Button("Pick Region", action: onSelectRegion)
                Button("Cancel", role: .cancel, action: onCancel)
            }
            Text(statusText)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            if let permissionMessage {
                HStack(spacing: 8) {
                    Text(permissionMessage)
                        .font(.caption)
                        .foregroundStyle(.orange)
                    Button("Grant Access", action: onRequestPermission)
                        .font(.caption)
                }
                .frame(maxWidth: 380, alignment: .leading)
            }
        }
        .padding(10)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.secondary.opacity(0.25), lineWidth: 1)
        )
        .shadow(radius: 6)
    }
}
