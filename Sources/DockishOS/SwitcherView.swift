import SwiftUI
import AppKit
import DockishOSCore

struct SwitcherView: View {
    @ObservedObject var store: WindowStore
    @ObservedObject var selection: SwitcherSelection
    /// Called when a tile is clicked. `SwitcherPanel` handles the keyboard.
    let onActivate: (WindowInfo) -> Void

    private var selectedWindow: WindowInfo? {
        store.windows.indices.contains(selection.index) ? store.windows[selection.index] : nil
    }

    var body: some View {
        VStack(spacing: Spacing.m) {
            ScrollView(.horizontal, showsIndicators: false) {
                ScrollViewReader { proxy in
                    HStack(spacing: Spacing.m) {
                        ForEach(Array(store.windows.enumerated()), id: \.element.id) { index, window in
                            Button {
                                selection.index = index
                                onActivate(window)
                            } label: {
                                SwitcherTile(
                                    window: window,
                                    isSelected: index == selection.index,
                                    isFirst: index == 0
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, Spacing.xl)
                    .padding(.top, Spacing.xl)
                    .onChange(of: selection.index) {
                        guard let selectedWindow else { return }
                        withAnimation(Motion.quick) {
                            proxy.scrollTo(selectedWindow.id, anchor: .center)
                        }
                    }
                }
            }

            if let selectedWindow {
                Text(selectedWindow.displayTitle)
                    .font(.body.weight(.medium))
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .padding(.horizontal, Spacing.xl)
                    .padding(.bottom, Spacing.xl)
            } else if store.windows.isEmpty {
                Text("No windows in this Space")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .padding(.bottom, Spacing.xl)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .floatingSurface(cornerRadius: Radius.panel)
    }
}

private struct SwitcherTile: View {
    let window: WindowInfo
    let isSelected: Bool
    let isFirst: Bool
    private static let iconSize: CGFloat = 64
    /// The icon plus a `Spacing.s` ring of selection fill on each side.
    private static let tileSize = iconSize + Spacing.s * 2

    var body: some View {
        VStack(spacing: Spacing.s) {
            ZStack {
                if let icon = NSRunningApplication(processIdentifier: window.pid)?.icon {
                    Image(nsImage: icon)
                        .resizable()
                        .frame(width: Self.iconSize, height: Self.iconSize)
                }
            }
            .frame(width: Self.tileSize, height: Self.tileSize)
            .background {
                if isSelected {
                    RoundedRectangle(cornerRadius: Radius.tile)
                        .fill(ChipStyle.frontmostFill)
                        .strokeBorder(ChipStyle.accent, lineWidth: 2)
                }
            }
            Text(window.ownerName)
                .font(.subheadline.weight(.medium))
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(width: Self.tileSize)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(window.ownerName), \(window.displayTitle)")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityHint(isFirst ? "Use Tab or arrow keys to choose a window, then press Return." : "")
    }
}
