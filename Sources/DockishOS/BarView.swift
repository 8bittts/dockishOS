import SwiftUI
import AppKit

struct BarView: View {
    let screen: NSScreen
    @ObservedObject var windowStore: WindowStore
    @ObservedObject var spacesStore: SpacesStore

    var body: some View {
        ZStack {
            VisualEffectView(material: .hudWindow, blending: .behindWindow)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .shadow(color: .black.opacity(0.35), radius: 18, y: 6)

            HStack(spacing: 8) {
                SpacesRow(
                    spaces: spacesStore.spaces(for: screen),
                    currentID: spacesStore.currentSpaceID(for: screen),
                    onPick: { spacesStore.switchTo($0) }
                )

                Divider()
                    .frame(height: 24)
                    .opacity(0.3)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(windowStore.windows) { window in
                            WindowChip(
                                window: window,
                                isFrontmost: window.pid == windowStore.frontmostPID,
                                onActivate: { windowStore.activate(window) },
                                onClose: { windowStore.close(window) }
                            )
                        }
                        if windowStore.windows.isEmpty {
                            Text("No windows on this Space")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 8)
                        }
                    }
                    .padding(.vertical, 10)
                }
            }
            .padding(.horizontal, 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct SpacesRow: View {
    let spaces: [SpaceInfo]
    let currentID: CGSSpaceID?
    let onPick: (SpaceInfo) -> Void

    var body: some View {
        HStack(spacing: 4) {
            ForEach(spaces) { space in
                SpaceChip(
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
    let index: Int
    let isActive: Bool
    let action: () -> Void
    @State private var hover = false

    var body: some View {
        Button(action: action) {
            Text("\(index)")
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundStyle(isActive ? .black : .primary)
                .frame(width: 24, height: 24)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(isActive ? Color.white.opacity(0.95) : Color.white.opacity(hover ? 0.18 : 0.08))
                )
        }
        .buttonStyle(.plain)
        .onHover { hover = $0 }
        .help(isActive ? "Space \(index) (current)" : "Switch to Space \(index)")
    }
}

private struct WindowChip: View {
    let window: WindowInfo
    let isFrontmost: Bool
    let onActivate: () -> Void
    let onClose: () -> Void
    @State private var hover = false

    var body: some View {
        Button(action: onActivate) {
            HStack(spacing: 6) {
                AppIconView(pid: window.pid)
                    .frame(width: 22, height: 22)
                Text(window.displayTitle)
                    .font(.system(size: 12, weight: isFrontmost ? .semibold : .medium))
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .foregroundStyle(.primary)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .frame(maxWidth: 220)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(chipFill)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isFrontmost ? Color.accentColor.opacity(0.85) : .clear, lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            hover = hovering
            if hovering {
                ThumbnailController.shared.requestShow(window, near: NSEvent.mouseLocation)
            } else {
                ThumbnailController.shared.cancelShow()
            }
        }
        .help(window.displayTitle)
        .contextMenu {
            Button("Activate") { onActivate() }
            Button("Close Window") { onClose() }
        }
    }

    private var chipFill: Color {
        if isFrontmost { return Color.white.opacity(0.22) }
        return Color.white.opacity(hover ? 0.18 : 0.08)
    }
}

private struct AppIconView: NSViewRepresentable {
    let pid: pid_t

    func makeNSView(context: Context) -> NSImageView {
        let v = NSImageView()
        v.imageScaling = .scaleProportionallyUpOrDown
        return v
    }

    func updateNSView(_ nsView: NSImageView, context: Context) {
        nsView.image = NSRunningApplication(processIdentifier: pid)?.icon
    }
}

struct VisualEffectView: NSViewRepresentable {
    var material: NSVisualEffectView.Material
    var blending: NSVisualEffectView.BlendingMode

    func makeNSView(context: Context) -> NSVisualEffectView {
        let v = NSVisualEffectView()
        v.material = material
        v.blendingMode = blending
        v.state = .active
        return v
    }

    func updateNSView(_ v: NSVisualEffectView, context: Context) {
        v.material = material
        v.blendingMode = blending
    }
}
