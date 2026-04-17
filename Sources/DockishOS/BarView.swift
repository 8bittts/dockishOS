import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct BarView: View {
    let screen: NSScreen
    @ObservedObject var windowStore: WindowStore
    @ObservedObject var spacesStore: SpacesStore
    @ObservedObject var pinnedStore: PinnedAppsStore
    @ObservedObject var settings: SettingsStore

    var body: some View {
        ZStack {
            VisualEffectView(material: .hudWindow, blending: .behindWindow)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .shadow(color: .black.opacity(0.35), radius: 18, y: 6)

            HStack(spacing: 8) {
                SpacesRow(
                    size: settings.barSize,
                    spaces: spacesStore.spaces(for: screen),
                    currentID: spacesStore.currentSpaceID(for: screen),
                    onPick: { spacesStore.switchTo($0) }
                )

                if settings.showPinnedRow {
                    Divider().frame(height: 24).opacity(0.3)
                    PinnedRow(
                        size: settings.barSize,
                        pins: pinnedStore.pins,
                        runningPIDs: Set(NSWorkspace.shared.runningApplications.compactMap(\.bundleIdentifier)),
                        onLaunch: { pinnedStore.launch($0) },
                        onUnpin:  { pinnedStore.unpin(bundleID: $0.bundleID) },
                        onMove:   { pinnedStore.move($0, by: $1) },
                        onReorder: { src, dst in pinnedStore.move(sourceID: src, onto: dst) }
                    )
                }

                Divider().frame(height: 24).opacity(0.3)

                WindowsRow(
                    windowStore: windowStore,
                    pinnedStore: pinnedStore,
                    settings: settings
                )
            }
            .padding(.horizontal, 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onDrop(of: [.fileURL], isTargeted: nil) { providers in
            handleFinderDrop(providers)
        }
    }

    private func handleFinderDrop(_ providers: [NSItemProvider]) -> Bool {
        var accepted = false
        for provider in providers where provider.canLoadObject(ofClass: URL.self) {
            accepted = true
            _ = provider.loadObject(ofClass: URL.self) { url, _ in
                guard let url else { return }
                DispatchQueue.main.async {
                    PinnedAppsStore.shared.pinAppBundle(at: url)
                }
            }
        }
        return accepted
    }
}

private struct WindowsRow: View {
    @ObservedObject var windowStore: WindowStore
    @ObservedObject var pinnedStore: PinnedAppsStore
    @ObservedObject var settings: SettingsStore

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                if settings.groupWindowsByApp {
                    let groups = windowStore.grouped()
                    ForEach(groups) { group in
                        groupChip(for: group)
                    }
                    if groups.isEmpty { emptyState }
                } else {
                    ForEach(windowStore.windows, id: \.id) { window in
                        chip(for: window)
                    }
                    if windowStore.windows.isEmpty { emptyState }
                }
            }
            .padding(.vertical, 10)
        }
    }

    @ViewBuilder
    private var emptyState: some View {
        Text("No windows on this Space")
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 8)
    }

    @ViewBuilder
    private func chip(for window: WindowInfo) -> some View {
        let isPinned = pinnedStore.isPinned(bundleID: window.bundleID)
        WindowChip(
            window: window,
            size: settings.barSize,
            showTitle: settings.showChipTitles,
            isFrontmost: window.pid == windowStore.frontmostPID,
            isPinned: isPinned,
            onActivate: { windowStore.activate(window) },
            onClose: { windowStore.close(window) },
            onTogglePin: {
                if let bid = window.bundleID, pinnedStore.isPinned(bundleID: bid) {
                    pinnedStore.unpin(bundleID: bid)
                } else {
                    pinnedStore.pin(window: window)
                }
            }
        )
    }

    @ViewBuilder
    private func groupChip(for group: WindowGroup) -> some View {
        let isPinned = pinnedStore.isPinned(bundleID: group.bundleID)
        let isFrontmost = group.windows.contains(where: { $0.pid == windowStore.frontmostPID })
        WindowGroupChip(
            group: group,
            size: settings.barSize,
            showTitle: settings.showChipTitles,
            isFrontmost: isFrontmost,
            isPinned: isPinned,
            previewWindow: windowStore.nextWindow(in: group),
            onActivateNext: { windowStore.activateNext(in: group) },
            onActivate: { windowStore.activate($0) },
            onClose: { windowStore.close($0) },
            onTogglePin: {
                if let bid = group.bundleID, pinnedStore.isPinned(bundleID: bid) {
                    pinnedStore.unpin(bundleID: bid)
                } else if let win = group.windows.first {
                    pinnedStore.pin(window: win)
                }
            }
        )
    }
}

private struct SpacesRow: View {
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
                        .fill(isActive ? Color.white.opacity(0.95) : Color.white.opacity(hover ? 0.18 : 0.08))
                )
        }
        .buttonStyle(.plain)
        .onHover { hover = $0 }
        .help(isActive ? "Space \(index) (current)" : "Switch to Space \(index)")
    }
}

private struct PinnedRow: View {
    let size: BarSize
    let pins: [PinnedApp]
    let runningPIDs: Set<String>
    let onLaunch: (PinnedApp) -> Void
    let onUnpin: (PinnedApp) -> Void
    let onMove: (PinnedApp, Int) -> Void
    let onReorder: (String, String) -> Void

    var body: some View {
        HStack(spacing: 4) {
            ForEach(pins) { app in
                PinnedChip(
                    app: app,
                    size: size,
                    isRunning: runningPIDs.contains(app.bundleID),
                    action: { onLaunch(app) },
                    onUnpin: { onUnpin(app) },
                    onMoveLeft: { onMove(app, -1) },
                    onMoveRight: { onMove(app, 1) }
                )
                .onDrag {
                    NSItemProvider(object: app.bundleID as NSString)
                }
                .onDrop(
                    of: [.text],
                    delegate: PinnedDropDelegate(targetID: app.bundleID, onReorder: onReorder)
                )
            }
            if pins.isEmpty {
                Text("Drop apps here")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.tertiary)
                    .padding(.horizontal, 6)
            }
        }
    }
}

private struct PinnedDropDelegate: DropDelegate {
    let targetID: String
    let onReorder: (String, String) -> Void

    func performDrop(info: DropInfo) -> Bool {
        guard let provider = info.itemProviders(for: [.text]).first else { return false }
        provider.loadObject(ofClass: NSString.self) { item, _ in
            guard let sourceID = item as? String, sourceID != targetID else { return }
            DispatchQueue.main.async { onReorder(sourceID, targetID) }
        }
        return true
    }
}

private struct PinnedChip: View {
    let app: PinnedApp
    let size: BarSize
    let isRunning: Bool
    let action: () -> Void
    let onUnpin: () -> Void
    let onMoveLeft: () -> Void
    let onMoveRight: () -> Void
    @State private var hover = false

    var body: some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Image(nsImage: NSWorkspace.shared.icon(forFile: app.path))
                    .resizable()
                    .frame(width: size.pinnedChipSize - 6, height: size.pinnedChipSize - 6)
                Circle()
                    .fill(isRunning ? Color.white.opacity(0.85) : Color.clear)
                    .frame(width: 4, height: 4)
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.white.opacity(hover ? 0.18 : 0.0))
            )
        }
        .buttonStyle(.plain)
        .onHover { hover = $0 }
        .help(app.name)
        .contextMenu {
            Button("Activate \(app.name)") { action() }
            Divider()
            Button("Move Left")  { onMoveLeft()  }
            Button("Move Right") { onMoveRight() }
            Divider()
            Button("Unpin") { onUnpin() }
        }
    }
}

private struct WindowChip: View {
    let window: WindowInfo
    let size: BarSize
    let showTitle: Bool
    let isFrontmost: Bool
    let isPinned: Bool
    let onActivate: () -> Void
    let onClose: () -> Void
    let onTogglePin: () -> Void
    @State private var hover = false

    var body: some View {
        Button(action: onActivate) {
            HStack(spacing: 6) {
                AppIconView(pid: window.pid)
                    .frame(width: size.chipIconSize, height: size.chipIconSize)
                if showTitle {
                    Text(window.displayTitle)
                        .font(.system(size: size.chipHeight * 0.40, weight: isFrontmost ? .semibold : .medium))
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .foregroundStyle(.primary)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .frame(height: size.chipHeight)
            .frame(maxWidth: showTitle ? 220 : nil)
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
            Divider()
            Button(isPinned ? "Unpin App from Bar" : "Pin App to Bar") { onTogglePin() }
        }
    }

    private var chipFill: Color {
        if isFrontmost { return Color.white.opacity(0.22) }
        return Color.white.opacity(hover ? 0.18 : 0.08)
    }
}

private struct WindowGroupChip: View {
    let group: WindowGroup
    let size: BarSize
    let showTitle: Bool
    let isFrontmost: Bool
    let isPinned: Bool
    let previewWindow: WindowInfo?
    let onActivateNext: () -> Void
    let onActivate: (WindowInfo) -> Void
    let onClose: (WindowInfo) -> Void
    let onTogglePin: () -> Void
    @State private var hover = false

    var body: some View {
        Button(action: onActivateNext) {
            HStack(spacing: 6) {
                AppIconView(pid: group.pid)
                    .frame(width: size.chipIconSize, height: size.chipIconSize)
                    .overlay(alignment: .topTrailing) {
                        if group.windows.count > 1 {
                            Text("\(group.windows.count)")
                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 1)
                                .background(Capsule().fill(Color.accentColor))
                                .offset(x: 6, y: -4)
                        }
                    }
                if showTitle {
                    Text(group.ownerName)
                        .font(.system(size: size.chipHeight * 0.40, weight: isFrontmost ? .semibold : .medium))
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .foregroundStyle(.primary)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .frame(height: size.chipHeight)
            .frame(maxWidth: showTitle ? 220 : nil)
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
            if hovering, let preview = previewWindow {
                ThumbnailController.shared.requestShow(preview, near: NSEvent.mouseLocation)
            } else {
                ThumbnailController.shared.cancelShow()
            }
        }
        .help("\(group.ownerName) — \(group.windows.count) window\(group.windows.count == 1 ? "" : "s")")
        .contextMenu {
            ForEach(group.windows, id: \.id) { window in
                Button(window.displayTitle.isEmpty ? "(untitled)" : window.displayTitle) {
                    onActivate(window)
                }
            }
            Divider()
            Button("Close All Windows") {
                for w in group.windows { onClose(w) }
            }
            Divider()
            Button(isPinned ? "Unpin App from Bar" : "Pin App to Bar") { onTogglePin() }
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
