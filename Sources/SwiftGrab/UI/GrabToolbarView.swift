import SwiftUI

struct GrabToolbarView: View {
    var isRegionMode: Bool
    var statusText: String
    var onSelectElement: () -> Void
    var onSelectRegion: () -> Void
    var onCancel: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            // Element mode
            toolbarIcon(
                systemName: "scope",
                isSelected: !isRegionMode,
                action: onSelectElement
            )

            divider

            // Region mode
            toolbarIcon(
                systemName: "rectangle.dashed",
                isSelected: isRegionMode,
                action: onSelectRegion
            )

            divider

            // Close
            Button(action: onCancel) {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Color(white: 0.55))
                    .frame(width: 32, height: 32)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .shadow(color: .black.opacity(0.12), radius: 6, y: 2)
        .shadow(color: .black.opacity(0.04), radius: 1, y: 1)
        .environment(\.colorScheme, .light)
    }

    private func toolbarIcon(
        systemName: String,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(isSelected ? Color.accentColor : Color(white: 0.55))
                .frame(width: 36, height: 32)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var divider: some View {
        Rectangle()
            .fill(Color(white: 0.9))
            .frame(width: 1, height: 16)
    }
}
