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
        VStack(spacing: 12) {
            ScrollView(.horizontal, showsIndicators: false) {
                ScrollViewReader { proxy in
                    HStack(spacing: 14) {
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
                    .padding(20)
                    .onChange(of: selection.index) {
                        guard let selectedWindow else { return }
                        withAnimation(.easeInOut(duration: 0.12)) {
                            proxy.scrollTo(selectedWindow.id, anchor: .center)
                        }
                    }
                }
            }

            if let selectedWindow {
                Text(selectedWindow.displayTitle)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 12)
            } else if store.windows.isEmpty {
                Text("No windows on this Space")
                    .foregroundStyle(.secondary)
                    .padding(.bottom, 12)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            VisualEffectView(material: .hudWindow, blending: .behindWindow)
                .clipShape(RoundedRectangle(cornerRadius: 18))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(Color(nsColor: .separatorColor).opacity(0.55), lineWidth: 0.5)
        )
    }
}

private struct SwitcherTile: View {
    let window: WindowInfo
    let isSelected: Bool
    let isFirst: Bool

    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                if let icon = NSRunningApplication(processIdentifier: window.pid)?.icon {
                    Image(nsImage: icon)
                        .resizable()
                        .frame(width: 64, height: 64)
                }
            }
            .frame(width: 84, height: 84)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(isSelected
                        ? Color(nsColor: .selectedContentBackgroundColor).opacity(0.35)
                        : Color(nsColor: .separatorColor).opacity(0.16))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(
                        isSelected ? ChipStyle.accent : Color(nsColor: .separatorColor).opacity(0.45),
                        lineWidth: isSelected ? 2 : 0.5
                    )
            )
            Text(window.ownerName)
                .font(.system(size: 11, weight: .medium))
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(width: 84)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(window.ownerName), \(window.displayTitle)")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityHint(isFirst ? "Use Tab or arrow keys to choose a window, then press Return." : "")
    }
}
