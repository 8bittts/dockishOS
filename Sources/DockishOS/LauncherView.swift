import SwiftUI
import AppKit

struct LauncherView: View {
    @ObservedObject var store: LauncherStore
    @ObservedObject var pinnedStore: PinnedAppsStore
    let onActivate: (AppEntry) -> Void
    let onDismiss: () -> Void
    @FocusState private var queryFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                    .font(.system(size: 16, weight: .medium))
                    .accessibilityHidden(true)
                TextField("Open application…", text: $store.query)
                    .textFieldStyle(.plain)
                    .font(.system(size: 18, weight: .regular))
                    .focused($queryFocused)
                    .accessibilityLabel("Open application")
                    .onSubmit { activateSelected() }
                if !store.query.isEmpty {
                    Button {
                        store.query = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("Clear")
                    .accessibilityLabel("Clear")
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 14)

            if !store.results.isEmpty {
                Divider().opacity(0.4)
                ResultsList(
                    store: store,
                    pinnedStore: pinnedStore,
                    onActivateSelected: activateSelected
                )
                .frame(maxHeight: 360)
            } else if !store.query.isEmpty {
                Divider().opacity(0.4)
                HStack {
                    Text("No matches")
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .padding(18)
            }
        }
        .background(
            VisualEffectView(material: .hudWindow, blending: .behindWindow)
                .clipShape(RoundedRectangle(cornerRadius: 14))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color(nsColor: .separatorColor).opacity(0.55), lineWidth: 0.5)
        )
        // The panel is taller than the search field alone: keep the HUD at its top.
        .frame(maxHeight: .infinity, alignment: .top)
        .onAppear { queryFocused = true }
        .onKeyPress(.upArrow) { store.moveSelection(by: -1); return .handled }
        .onKeyPress(.downArrow) { store.moveSelection(by: 1); return .handled }
        .onKeyPress(.escape) { onDismiss(); return .handled }
        .onKeyPress(.return) { activateSelected(); return .handled }
    }

    private func activateSelected() {
        if let app = store.selectedApp {
            onActivate(app)
        }
    }
}

private struct ResultsList: View {
    @ObservedObject var store: LauncherStore
    @ObservedObject var pinnedStore: PinnedAppsStore
    let onActivateSelected: () -> Void

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(Array(store.results.enumerated()), id: \.element.id) { index, app in
                        Button {
                            store.selectedIndex = index
                            onActivateSelected()
                        } label: {
                            AppRow(app: app, isSelected: index == store.selectedIndex)
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            if let bundleID = app.bundleID, pinnedStore.isPinned(bundleID: bundleID) {
                                Button("Unpin from Bar") { pinnedStore.unpin(bundleID: bundleID) }
                            } else {
                                Button("Pin to Bar") { pinnedStore.pin(app) }
                            }
                        }
                    }
                }
                .padding(.vertical, 6)
            }
            // Rows are identified by app, never by position: a row keyed by
            // its index keeps showing the app that held that index before.
            .onChange(of: store.selectedIndex) {
                guard let selected = store.selectedApp else { return }
                withAnimation(.easeInOut(duration: 0.1)) {
                    proxy.scrollTo(selected.id, anchor: .center)
                }
            }
        }
    }
}

private struct AppRow: View {
    let app: AppEntry
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 10) {
            // Load the icon on the main thread here rather than materializing
            // NSImages off-main during the background app scan (LaunchServices
            // caches, so this is cheap).
            Image(nsImage: NSWorkspace.shared.icon(forFile: app.path.path))
                .resizable()
                .frame(width: 28, height: 28)
            VStack(alignment: .leading, spacing: 1) {
                Text(app.name)
                    .font(.system(size: 13, weight: .medium))
                if let bid = app.bundleID {
                    Text(bid)
                        .font(.system(size: 10, weight: .regular, design: .monospaced))
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
        .background(
            isSelected ? ChipStyle.accent.opacity(0.25) : Color.clear
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(app.name)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
