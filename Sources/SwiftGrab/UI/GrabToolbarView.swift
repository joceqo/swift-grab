import SwiftUI

struct GrabToolbarView: View {
    var isRegionMode: Bool
    var statusText: String
    var onSelectElement: () -> Void
    var onSelectRegion: () -> Void
    var onCancel: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 12) {
                modePicker
                closeButton
            }

            Text(statusText)
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
                .lineLimit(1)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.2), radius: 12, y: 4)
    }

    // MARK: - Mode picker (segmented)

    private var modePicker: some View {
        HStack(spacing: 2) {
            modeTab(
                title: "Element",
                icon: "scope",
                isSelected: !isRegionMode,
                action: onSelectElement
            )
            modeTab(
                title: "Region",
                icon: "rectangle.dashed",
                isSelected: isRegionMode,
                action: onSelectRegion
            )
        }
        .padding(3)
        .background(Color.primary.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private func modeTab(
        title: String,
        icon: String,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .font(.system(size: 12, weight: isSelected ? .semibold : .regular))
                .foregroundStyle(isSelected ? .white : .secondary)
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(isSelected ? Color.accentColor : Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Close button

    private var closeButton: some View {
        Button(action: onCancel) {
            Image(systemName: "xmark")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.secondary)
                .frame(width: 22, height: 22)
                .background(Color.primary.opacity(0.08))
                .clipShape(Circle())
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
    }
}
