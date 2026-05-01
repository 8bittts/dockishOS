import SwiftUI
import AppKit

struct SwitcherView: View {
    @ObservedObject var store: WindowStore
    @Binding var selectedIndex: Int
    let onActivate: (WindowInfo) -> Void
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            ScrollView(.horizontal, showsIndicators: false) {
                ScrollViewReader { proxy in
                    HStack(spacing: 14) {
                        ForEach(Array(store.windows.enumerated()), id: \.element.id) { index, window in
                            SwitcherTile(
                                window: window,
                                isSelected: index == selectedIndex,
                                isFirst: index == 0
                            )
                            .id(index)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                selectedIndex = index
                                onActivate(window)
                            }
                        }
                    }
                    .padding(20)
                    .onChange(of: selectedIndex) { _, new in
                        withAnimation(.easeInOut(duration: 0.12)) {
                            proxy.scrollTo(new, anchor: .center)
                        }
                    }
                }
            }

            if store.windows.indices.contains(selectedIndex) {
                Text(store.windows[selectedIndex].displayTitle)
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
        .background(
            VisualEffectView(material: .hudWindow, blending: .behindWindow)
                .clipShape(RoundedRectangle(cornerRadius: 18))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(Color.white.opacity(0.12), lineWidth: 0.5)
        )
        .onKeyPress(.return)     { activate(); return .handled }
        .onKeyPress(.escape)     { onDismiss(); return .handled }
        .onKeyPress(.leftArrow)  { advance(by: -1); return .handled }
        .onKeyPress(.rightArrow) { advance(by: 1); return .handled }
    }

    private func advance(by delta: Int) {
        guard !store.windows.isEmpty else { return }
        let count = store.windows.count
        selectedIndex = (selectedIndex + delta + count) % count
    }

    private func activate() {
        guard store.windows.indices.contains(selectedIndex) else { return }
        onActivate(store.windows[selectedIndex])
    }
}

private struct SwitcherTile: View {
    let window: WindowInfo
    let isSelected: Bool
    let isFirst: Bool

    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                if let app = NSRunningApplication(processIdentifier: window.pid),
                   let icon = app.icon {
                    Image(nsImage: icon)
                        .resizable()
                        .frame(width: 64, height: 64)
                }
            }
            .frame(width: 84, height: 84)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(isSelected ? Color.accentColor.opacity(0.30) : Color.white.opacity(0.06))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(isSelected ? Color.accentColor : Color.white.opacity(0.08),
                            lineWidth: isSelected ? 2 : 0.5)
            )
            Text(window.ownerName)
                .font(.system(size: 11, weight: .medium))
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(width: 84)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(window.ownerName), \(window.displayTitle)")
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : [.isButton])
        .accessibilityHint(isFirst ? "Use Tab or arrow keys to choose a window, then press Return." : "")
    }
}
