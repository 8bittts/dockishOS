import SwiftUI

/// Numbered chips for every Space on the bar's display, with the current
/// one highlighted. Click to switch.
struct SpacesRow: View {
    let size: BarSize
    let spaces: [SpaceInfo]
    let currentID: CGSSpaceID?
    let onPick: (SpaceInfo) -> Void

    var body: some View {
        HStack(spacing: 4) {
            ForEach(spaces) { space in
                SpaceChip(
                    size: size,
                    index: space.index,
                    isActive: space.id == currentID,
                    action: { onPick(space) }
                )
            }
            if spaces.isEmpty {
                Text("—")
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.tertiary)
            }
        }
    }
}

private struct SpaceChip: View {
    let size: BarSize
    let index: Int
    let isActive: Bool
    let action: () -> Void
    @State private var hover = false

    var body: some View {
        Button(action: action) {
            Text("\(index)")
                .font(.system(size: size.spaceChipSize * 0.45, weight: .bold, design: .monospaced))
                .foregroundStyle(isActive ? .black : .primary)
                .frame(width: size.spaceChipSize, height: size.spaceChipSize)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(isActive
                              ? Color.white.opacity(0.95)
                              : Color.white.opacity(hover ? ChipStyle.hoverOpacity : ChipStyle.inactiveOpacity))
                )
        }
        .buttonStyle(.plain)
        .onHover { hover = $0 }
        .help(isActive ? "Space \(index) (current)" : "Switch to Space \(index)")
        .accessibilityLabel(isActive ? "Space \(index), current" : "Switch to Space \(index)")
    }
}
