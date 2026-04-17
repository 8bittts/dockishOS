import SwiftUI
import AppKit

struct LauncherView: View {
    @ObservedObject var store: LauncherStore
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
                    .onSubmit { store.activateSelected() }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 14)

            if !store.results.isEmpty {
                Divider().opacity(0.4)
                ResultsList(store: store)
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
                .stroke(Color.white.opacity(0.12), lineWidth: 0.5)
        )
        .onAppear { queryFocused = true }
        .onKeyPress(.upArrow) { store.moveSelection(by: -1); return .handled }
        .onKeyPress(.downArrow) { store.moveSelection(by: 1); return .handled }
        .onKeyPress(.escape) { LauncherController.shared.hide(); return .handled }
        .onKeyPress(.return) { store.activateSelected(); return .handled }
    }
}

private struct ResultsList: View {
    @ObservedObject var store: LauncherStore

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
                                store.activateSelected()
                            }
                            .contextMenu {
                                if PinnedAppsStore.shared.isPinned(bundleID: app.bundleID) {
                                    Button("Unpin from Bar") {
                                        if let bid = app.bundleID {
                                            PinnedAppsStore.shared.unpin(bundleID: bid)
                                        }
                                    }
                                } else {
                                    Button("Pin to Bar") {
                                        PinnedAppsStore.shared.pin(app)
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
            Image(nsImage: app.icon)
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
            isSelected ? Color.accentColor.opacity(0.25) : Color.clear
        )
    }
}
