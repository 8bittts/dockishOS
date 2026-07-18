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
                TextField("Open application…", text: $store.query)
                    .textFieldStyle(.plain)
                    .font(.system(size: 18, weight: .regular))
                    .focused($queryFocused)
                    .onSubmit { activateSelected() }
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
        .onAppear { queryFocused = true }
        .onKeyPress(.upArrow) { store.moveSelection(by: -1); return .handled }
        .onKeyPress(.downArrow) { store.moveSelection(by: 1); return .handled }
        .onKeyPress(.escape) { onDismiss(); return .handled }
        .onKeyPress(.return) { activateSelected(); return .handled }
    }

    private func activateSelected() {
        guard let app = store.selectedApp() else { return }
        onActivate(app)
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
                        AppRow(app: app, isSelected: index == store.selectedIndex)
                            .id(index)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                store.selectedIndex = index
                                onActivateSelected()
                            }
                            .contextMenu {
                                if pinnedStore.isPinned(bundleID: app.bundleID) {
                                    Button("Unpin from Bar") {
                                        if let bid = app.bundleID {
                                            pinnedStore.unpin(bundleID: bid)
                                        }
                                    }
                                } else {
                                    Button("Pin to Bar") {
                                        pinnedStore.pin(app)
                                    }
                                }
                            }
                    }
                }
                .padding(.vertical, 6)
            }
            .onChange(of: store.selectedIndex) { _, newValue in
                withAnimation(.easeInOut(duration: 0.1)) {
                    proxy.scrollTo(newValue, anchor: .center)
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
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : [.isButton])
    }
}
