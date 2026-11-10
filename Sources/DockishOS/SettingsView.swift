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

    var body: some View {
        Form {
            HotkeySettingsSection(settings: settings)
            AccessibilitySettingsSection()
            CollapseSettingsSection(settings: settings)
            LoginSettingsSection()
            DisplaySettingsSection(settings: settings)
        }
        .formStyle(.grouped)
        .padding(.horizontal, 12)
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
                resetValue: .launcherDefault
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

private struct CollapseSettingsSection: View {
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
    @Binding var hotkey: Hotkey
    let resetValue: Hotkey

    var body: some View {
        HStack {
            Text(title)
            Spacer()
            HotkeyRecorder(title: title, hotkey: $hotkey)
                .frame(width: 160, height: 26)
            Button("Reset") { hotkey = resetValue }
                .controlSize(.small)
                .accessibilityLabel("Reset \(title)")
        }
    }
}

private struct LoginSettingsSection: View {
    @State private var isEnabled = LoginItem.isEnabled
    @State private var status = LoginItem.statusDescription

    var body: some View {
        Section {
            Toggle("Launch DockishOS at login", isOn: Binding(
                get: { isEnabled },
                set: { newValue in
                    LoginItem.setEnabled(newValue)
                    refresh()
                }
            ))
        } header: {
            Text("Login")
        } footer: {
            FooterText(status)
        }
        .onAppear(perform: refresh)
    }

    /// Reads the state back from the system: registering can fail or wait
    /// for the user's approval.
    private func refresh() {
        isEnabled = LoginItem.isEnabled
        status = LoginItem.statusDescription
    }
}

private struct DisplaySettingsSection: View {
    private struct Display: Identifiable {
        let id: String
        let name: String

        @MainActor
        static func connected() -> [Display] {
            let items = NSScreen.screens.map {
                DisplayNameDisambiguator.Item(id: $0.displayUUID, name: $0.localizedName)
            }
            return DisplayNameDisambiguator.disambiguate(items).map { Display(id: $0.id, name: $0.name) }
        }
    }

    @ObservedObject var settings: SettingsStore
    @State private var displays = Display.connected()

    var body: some View {
        Section {
            ForEach(displays) { display in
                Toggle(display.name, isOn: Binding(
                    get: { !settings.disabledScreenUUIDs.contains(display.id) },
                    set: { settings.setScreen(display.id, enabled: $0) }
                ))
            }
        } header: {
            Text("Displays")
        } footer: {
            FooterText("Turn off displays where you don't want a bar. Bars rebuild instantly.")
        }
        .onReceive(NotificationCenter.default.publisher(
            for: NSApplication.didChangeScreenParametersNotification
        )) { _ in
            displays = Display.connected()
        }
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
            Text("Right-click any window chip on the bar and choose **Pin to Bar**, or right-click a result in the launcher to pin it.")
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
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 1) {
                Text(app.name).font(.body.weight(.medium))
                Text(app.bundleID)
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            Spacer()
            PinnedListIconButton(
                systemName: "chevron.up",
                label: "Move Up",
                disabled: isFirst,
                action: onUp
            )
            PinnedListIconButton(
                systemName: "chevron.down",
                label: "Move Down",
                disabled: isLast,
                action: onDown
            )
            PinnedListIconButton(
                systemName: "xmark.circle.fill",
                label: "Unpin from Bar",
                disabled: false,
                action: onRemove
            )
            .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
}

private struct PinnedListIconButton: View {
    let systemName: String
    let label: String
    let disabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .frame(width: 20, height: 20)
                .contentShape(Rectangle())
        }
        .buttonStyle(.borderless)
        .disabled(disabled)
        .help(label)
        .accessibilityLabel(label)
    }
}

private struct AboutTab: View {
    var body: some View {
        VStack(spacing: 14) {
            Image(nsImage: DockishBrandAssets.applicationIcon(size: NSSize(width: 112, height: 112)))
                .interpolation(.high)
                .accessibilityHidden(true)
            Text("DockishOS")
                .font(.title.weight(.semibold))
            Text("v\(AppVersion.short) (build \(AppVersion.build))")
                .font(.system(.callout, design: .monospaced))
                .foregroundStyle(.secondary)
            if !AppVersion.copyright.isEmpty {
                Text(AppVersion.copyright)
                    .font(.footnote)
                    .foregroundStyle(.tertiary)
            }
            Text("A Dock alternative for power users of macOS Spaces.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 40)
            HStack(spacing: 16) {
                Link("GitHub", destination: AppLinks.repository)
                Link("Releases", destination: AppLinks.releases)
                Link("MIT License", destination: AppLinks.license)
            }
            .font(.callout)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(20)
    }
}
