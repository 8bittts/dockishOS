import SwiftUI
import AppKit

struct SettingsView: View {
    @ObservedObject var settings: SettingsStore
    @ObservedObject var pinned: PinnedAppsStore

    var body: some View {
        TabView {
            AppearanceTab(settings: settings)
                .tabItem { Label("Appearance", systemImage: "slider.horizontal.3") }
            BehaviorTab()
                .tabItem { Label("Behavior", systemImage: "gearshape.2") }
            PinnedTab(pinned: pinned)
                .tabItem { Label("Pinned", systemImage: "pin") }
            AboutTab()
                .tabItem { Label("About", systemImage: "info.circle") }
        }
        .frame(width: 480, height: 460)
        .padding(.top, 4)
    }
}

private struct AppearanceTab: View {
    @ObservedObject var settings: SettingsStore

    var body: some View {
        Form {
            Section {
                Picker("Bar size", selection: $settings.barSize) {
                    ForEach(BarSize.allCases) { size in
                        Text(size.displayName).tag(size)
                    }
                }
                .pickerStyle(.segmented)

                Picker("Bar position", selection: $settings.barPosition) {
                    ForEach(BarPosition.allCases) { pos in
                        Text(pos.displayName).tag(pos)
                    }
                }
                .pickerStyle(.segmented)

                Toggle("Show window titles on chips", isOn: $settings.showChipTitles)
                Toggle("Show pinned apps row", isOn: $settings.showPinnedRow)
            } header: {
                Text("Bar")
            } footer: {
                Text("Size and position changes apply immediately to every connected display.")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding(.horizontal, 12)
    }
}

private struct BehaviorTab: View {
    @ObservedObject var settings: SettingsStore = SettingsStore.shared
    @State private var dockAutoHide: Bool = DockHelper.isAutoHideEnabled
    @State private var loginItemEnabled: Bool = LoginItem.isEnabled
    @State private var loginItemMessage: String = LoginItem.statusDescription
    @State private var screens: [ScreenItem] = []

    var body: some View {
        Form {
            Section {
                HStack {
                    Text("Launcher hotkey")
                    Spacer()
                    HotkeyRecorder(
                        hotkey: $settings.launcherHotkey,
                        onReset: { settings.launcherHotkey = .default }
                    )
                    .frame(width: 160, height: 26)
                    Button("Reset") { settings.launcherHotkey = .default }
                        .controlSize(.small)
                }
            } header: {
                Text("Hotkey")
            } footer: {
                Text("Click the field, press the new chord. Press Esc to cancel. Must include at least one non-shift modifier.")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }

            Section {
                Toggle("Auto-hide system Dock", isOn: $dockAutoHide)
                    .onChange(of: dockAutoHide) { _, newValue in
                        DockHelper.setAutoHide(newValue)
                    }
            } header: {
                Text("System Dock")
            } footer: {
                Text("Toggling this restarts the macOS Dock to apply.")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }

            Section {
                Toggle("Launch DockishOS at login", isOn: $loginItemEnabled)
                    .onChange(of: loginItemEnabled) { _, newValue in
                        _ = LoginItem.setEnabled(newValue)
                        loginItemEnabled = LoginItem.isEnabled
                        loginItemMessage = LoginItem.statusDescription
                    }
            } header: {
                Text("Login")
            } footer: {
                Text(loginItemMessage)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }

            Section {
                if screens.isEmpty {
                    Text("Detecting displays…")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(screens) { screen in
                        Toggle(screen.name, isOn: enabledBinding(for: screen))
                    }
                }
            } header: {
                Text("Displays")
            } footer: {
                Text("Turn off displays where you don't want a bar. Bars rebuild instantly.")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding(.horizontal, 12)
        .onAppear {
            dockAutoHide = DockHelper.isAutoHideEnabled
            loginItemEnabled = LoginItem.isEnabled
            loginItemMessage = LoginItem.statusDescription
            reloadScreens()
        }
    }

    private func reloadScreens() {
        screens = NSScreen.screens.map { ns in
            let uuid = SpacesAPI.displayUUID(for: ns)
            return ScreenItem(
                id: uuid,
                name: ns.localizedName,
                isEnabled: !settings.disabledScreenUUIDs.contains(uuid)
            )
        }
    }

    private func enabledBinding(for screen: ScreenItem) -> Binding<Bool> {
        Binding(
            get: { !settings.disabledScreenUUIDs.contains(screen.id) },
            set: { newValue in
                var set = settings.disabledScreenUUIDs
                if newValue { set.remove(screen.id) } else { set.insert(screen.id) }
                settings.disabledScreenUUIDs = set
                reloadScreens()
            }
        )
    }
}

private struct ScreenItem: Identifiable, Hashable {
    let id: String
    let name: String
    let isEnabled: Bool
}

private struct HotkeyRecorder: NSViewRepresentable {
    @Binding var hotkey: LauncherHotkey
    var onReset: () -> Void

    func makeNSView(context: Context) -> HotkeyRecorderView {
        let v = HotkeyRecorderView()
        v.hotkey = hotkey
        v.onChange = { hotkey = $0 }
        return v
    }

    func updateNSView(_ nsView: HotkeyRecorderView, context: Context) {
        nsView.hotkey = hotkey
    }
}

private struct PinnedTab: View {
    @ObservedObject var pinned: PinnedAppsStore

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if pinned.pins.isEmpty {
                EmptyPinnedState()
            } else {
                PinnedList(pinned: pinned)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(12)
    }
}

private struct EmptyPinnedState: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "pin.slash")
                .font(.system(size: 36, weight: .light))
                .foregroundStyle(.tertiary)
            Text("No pinned apps yet")
                .font(.headline)
            Text("Right-click any window chip on the bar and choose **Pin App to Bar**, or right-click a result in the launcher to pin it.")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct PinnedList: View {
    @ObservedObject var pinned: PinnedAppsStore

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                ForEach(Array(pinned.pins.enumerated()), id: \.element.id) { index, app in
                    PinnedRow(
                        app: app,
                        isFirst: index == 0,
                        isLast: index == pinned.pins.count - 1,
                        onUp: { pinned.move(app, by: -1) },
                        onDown: { pinned.move(app, by: 1) },
                        onRemove: { pinned.unpin(bundleID: app.bundleID) }
                    )
                    if index < pinned.pins.count - 1 {
                        Divider().opacity(0.3)
                    }
                }
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(nsColor: .underPageBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.gray.opacity(0.2), lineWidth: 0.5)
        )
    }
}

private struct PinnedRow: View {
    let app: PinnedApp
    let isFirst: Bool
    let isLast: Bool
    let onUp: () -> Void
    let onDown: () -> Void
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(nsImage: NSWorkspace.shared.icon(forFile: app.path))
                .resizable()
                .frame(width: 28, height: 28)
            VStack(alignment: .leading, spacing: 1) {
                Text(app.name).font(.system(size: 13, weight: .medium))
                Text(app.bundleID)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            Spacer()
            Button(action: onUp) { Image(systemName: "chevron.up") }
                .buttonStyle(.borderless)
                .disabled(isFirst)
            Button(action: onDown) { Image(systemName: "chevron.down") }
                .buttonStyle(.borderless)
                .disabled(isLast)
            Button(action: onRemove) { Image(systemName: "xmark.circle.fill") }
                .buttonStyle(.borderless)
                .foregroundStyle(.secondary)
                .help("Unpin")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
}

private struct AboutTab: View {
    private var version: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "dev"
    }
    private var build: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?"
    }

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "dock.rectangle")
                .font(.system(size: 56, weight: .regular))
                .foregroundStyle(.tint)
            Text("DockishOS")
                .font(.system(size: 22, weight: .semibold))
            Text("v\(version) (build \(build))")
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(.secondary)
            Text("A Dock alternative for power users of macOS Spaces.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 40)
            HStack(spacing: 16) {
                Link("GitHub", destination: URL(string: "https://github.com/8bittts/dockishOS")!)
                Link("Releases", destination: URL(string: "https://github.com/8bittts/dockishOS/releases")!)
                Link("MIT License", destination: URL(string: "https://github.com/8bittts/dockishOS/blob/main/LICENSE")!)
            }
            .font(.system(size: 12))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(20)
    }
}
