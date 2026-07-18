import SwiftUI
import AppKit
import DockishOSCore

struct SettingsView: View {
    @ObservedObject var settings: SettingsStore
    @ObservedObject var pinned: PinnedAppsStore

    var body: some View {
        TabView {
            AppearanceTab(settings: settings)
                .tabItem { Label("Appearance", systemImage: "slider.horizontal.3") }
            BehaviorTab(settings: settings)
                .tabItem { Label("Behavior", systemImage: "gearshape.2") }
            PinnedTab(pinned: pinned)
                .tabItem { Label("Pinned", systemImage: "pin") }
            AboutTab()
                .tabItem { Label("About", systemImage: "info.circle") }
        }
        .frame(minWidth: 480, minHeight: 460)
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
                Toggle("Group windows by app", isOn: $settings.groupWindowsByApp)
            } header: {
                Text("Bar")
            } footer: {
                FooterText("Size and position changes apply immediately to every connected display.")
            }

            Section {
                Toggle("Show notification badges", isOn: $settings.showNotificationBadges)
            } header: {
                Text("Notifications")
            } footer: {
                FooterText("Reads badge counts from the macOS Dock's accessibility tree (every 2.5 s). Uses an undocumented Dock attribute that may break in future macOS releases — disable here if it misbehaves.")
            }
        }
        .formStyle(.grouped)
        .padding(.horizontal, 12)
    }
}

private struct BehaviorTab: View {
    @ObservedObject var settings: SettingsStore
    @State private var loginItemEnabled: Bool = LoginItem.isEnabled
    @State private var loginItemMessage: String = LoginItem.statusDescription
    @State private var screens: [ScreenItem] = []

    var body: some View {
        Form {
            HotkeySettingsSection(settings: settings)
            AccessibilitySettingsSection()
            UtilitySettingsSection(settings: settings)
            LoginSettingsSection(
                loginItemEnabled: $loginItemEnabled,
                loginItemMessage: $loginItemMessage
            )
            DisplaySettingsSection(settings: settings, screens: screens)
        }
        .formStyle(.grouped)
        .padding(.horizontal, 12)
        .onAppear(perform: refreshState)
        .onReceive(NotificationCenter.default.publisher(
            for: NSApplication.didChangeScreenParametersNotification
        )) { _ in
            reloadScreens()
        }
    }

    private func refreshState() {
        loginItemEnabled = LoginItem.isEnabled
        loginItemMessage = LoginItem.statusDescription
        reloadScreens()
    }

    private func reloadScreens() {
        screens = ScreenItem.snapshot()
    }
}

private struct AccessibilitySettingsSection: View {
    @State private var granted = Permissions.isAccessibilityGranted

    var body: some View {
        Section {
            HStack {
                Text("Accessibility")
                Spacer()
                Label(granted ? "Granted" : "Not Granted", systemImage: granted ? "checkmark.circle.fill" : "exclamationmark.circle")
                    .foregroundStyle(granted ? .green : .secondary)
            }
            Button("Open Accessibility Settings") {
                Permissions.requestAccessibilityFromSettings()
                refresh()
            }
            Button("Check Again") {
                refresh()
            }
        } header: {
            Text("Permissions")
        } footer: {
            FooterText("Accessibility lets DockishOS raise and close specific windows from the bar.")
        }
        .onAppear(perform: refresh)
    }

    private func refresh() {
        granted = Permissions.isAccessibilityGranted
    }
}

private struct HotkeySettingsSection: View {
    @ObservedObject var settings: SettingsStore

    var body: some View {
        Section {
            HotkeyRecorderRow(
                title: "Launcher hotkey",
                hotkey: $settings.launcherHotkey,
                resetValue: .default
            )
            HotkeyRecorderRow(
                title: "App switcher hotkey",
                hotkey: $settings.switcherHotkey,
                resetValue: .switcherDefault
            )
        } header: {
            Text("Hotkeys")
        } footer: {
            FooterText("Click a field, press the new chord. Esc cancels. Each chord must include at least one non-shift modifier.")
        }
    }
}

private struct ScreenItem: Identifiable, Hashable {
    let id: String
    let name: String

    static func snapshot() -> [ScreenItem] {
        let items = NSScreen.screens.map { screen in
            DisplayNameDisambiguator.Item(
                id: SpacesAPI.displayUUID(for: screen),
                name: screen.localizedName
            )
        }
        return DisplayNameDisambiguator.disambiguate(items).map { ScreenItem(id: $0.id, name: $0.name) }
    }
}

private struct UtilitySettingsSection: View {
    @ObservedObject var settings: SettingsStore

    var body: some View {
        Section {
            Toggle("Collapse bar into edge tab", isOn: $settings.barCollapsed)

            Picker("Collapsed tab position", selection: $settings.collapsedTabPosition) {
                ForEach(CollapsedTabPosition.allCases) { position in
                    Text(position.displayName).tag(position)
                }
            }
        } header: {
            Text("Bar Controls")
        } footer: {
            FooterText("Slides the full bar offscreen and leaves a small edge tab. You can anchor that tab to the bottom-left or bottom-right corner.")
        }
    }
}

private struct HotkeyRecorderRow: View {
    let title: String
    @Binding var hotkey: LauncherHotkey
    let resetValue: LauncherHotkey

    var body: some View {
        HStack {
            Text(title)
            Spacer()
            HotkeyRecorder(hotkey: $hotkey)
                .frame(width: 160, height: 26)
            Button("Reset") { hotkey = resetValue }
                .controlSize(.small)
        }
    }
}

private struct LoginSettingsSection: View {
    @Binding var loginItemEnabled: Bool
    @Binding var loginItemMessage: String

    var body: some View {
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
            FooterText(loginItemMessage)
        }
    }
}

private struct DisplaySettingsSection: View {
    @ObservedObject var settings: SettingsStore
    let screens: [ScreenItem]

    var body: some View {
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
            FooterText("Turn off displays where you don't want a bar. Bars rebuild instantly.")
        }
    }

    private func enabledBinding(for screen: ScreenItem) -> Binding<Bool> {
        Binding(
            get: { !settings.disabledScreenUUIDs.contains(screen.id) },
            set: { newValue in
                var disabled = settings.disabledScreenUUIDs
                if newValue {
                    disabled.remove(screen.id)
                } else {
                    disabled.insert(screen.id)
                }
                settings.disabledScreenUUIDs = disabled
            }
        )
    }
}

private struct FooterText: View {
    let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        Text(text)
            .font(.subheadline)
            .foregroundStyle(.secondary)
    }
}

private struct HotkeyRecorder: NSViewRepresentable {
    @Binding var hotkey: LauncherHotkey

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
        ContentUnavailableView {
            Label("No pinned apps yet", systemImage: "pin.slash")
        } description: {
            Text("Right-click any window chip on the bar and choose **Pin App to Bar**, or right-click a result in the launcher to pin it.")
        }
    }
}

private struct PinnedList: View {
    @ObservedObject var pinned: PinnedAppsStore

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                ForEach(Array(pinned.pins.enumerated()), id: \.element.id) { index, app in
                    PinnedAppRow(
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
                .stroke(Color(nsColor: .separatorColor), lineWidth: 0.5)
        )
    }
}

private struct PinnedAppRow: View {
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
                Text(app.name).font(.body.weight(.medium))
                Text(app.bundleID)
                    .font(.system(.caption2, design: .monospaced))
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
    private var version: String { AppVersion.short }
    private var build: String { AppVersion.build }

    var body: some View {
        VStack(spacing: 14) {
            Image(nsImage: DockishBrandAssets.applicationIcon(size: NSSize(width: 112, height: 112)))
                .interpolation(.high)
            Text("DockishOS")
                .font(.title.weight(.semibold))
            Text("v\(version) (build \(build))")
                .font(.system(.callout, design: .monospaced))
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
            .font(.callout)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(20)
    }
}
