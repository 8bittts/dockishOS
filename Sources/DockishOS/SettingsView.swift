import SwiftUI
import AppKit
import DockishOSCore

/// The panes of the Settings window, in toolbar order.
enum SettingsPane: CaseIterable {
    case appearance, behavior, pinned, about

    static let size = NSSize(width: 480, height: 460)

    var title: String {
        switch self {
        case .appearance: return "Appearance"
        case .behavior:   return "Behavior"
        case .pinned:     return "Pinned"
        case .about:      return "About"
        }
    }

    var symbolName: String {
        switch self {
        case .appearance: return "slider.horizontal.3"
        case .behavior:   return "gearshape.2"
        case .pinned:     return "pin"
        case .about:      return "info.circle"
        }
    }
}

/// One Settings pane at the window's fixed size.
struct SettingsPaneView: View {
    let pane: SettingsPane

    var body: some View {
        Group {
            switch pane {
            case .appearance: AppearanceTab(settings: .shared)
            case .behavior:   BehaviorTab(settings: .shared)
            case .pinned:     PinnedTab(pinned: .shared)
            case .about:      AboutTab()
            }
        }
        .frame(width: SettingsPane.size.width, height: SettingsPane.size.height)
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
                Toggle("Show pinned apps", isOn: $settings.showPinnedRow)
                Toggle("Group windows by app", isOn: $settings.groupWindowsByApp)
            } header: {
                Text("Bar")
            } footer: {
                Text("Size and position apply to the bar on every display.")
            }

            Section {
                Toggle("Show notification badges", isOn: $settings.showNotificationBadges)
            } header: {
                Text("Notifications")
            } footer: {
                Text("Shows each app's Dock badge on its chip. DockishOS reads badges from the Dock with Accessibility, and a future macOS release can stop that from working.")
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
            ShortcutSettingsSection(settings: settings)
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
            Text("Accessibility lets DockishOS raise or close one window, and read Dock badges.")
        }
        .onAppear(perform: refresh)
    }

    private func refresh() {
        granted = Permissions.isAccessibilityGranted
    }
}

private struct ShortcutSettingsSection: View {
    @ObservedObject var settings: SettingsStore

    var body: some View {
        Section {
            HStack {
                Text("App switcher")
                Spacer()
                HotkeyRecorder(title: "App switcher shortcut", hotkey: $settings.switcherHotkey)
                    .frame(width: 160, height: 26)
                Button("Reset") { settings.switcherHotkey = .switcherDefault }
                    .controlSize(.small)
                    .accessibilityLabel("Reset app switcher shortcut")
            }
        } header: {
            Text("Keyboard Shortcut")
        } footer: {
            Text("Click the field, then press the new shortcut. Press Esc to cancel. A shortcut needs Control, Option, or Command.")
        }
    }
}

private struct CollapseSettingsSection: View {
    @ObservedObject var settings: SettingsStore

    var body: some View {
        Section {
            Toggle("Collapse bar into edge tab", isOn: $settings.barCollapsed)

            Picker("Edge tab position", selection: $settings.collapsedTabPosition) {
                ForEach(CollapsedTabPosition.allCases) { position in
                    Text(position.displayName).tag(position)
                }
            }
        } header: {
            Text("Edge Tab")
        } footer: {
            Text("Collapsing slides the bar off the screen and leaves a small tab in the corner you choose.")
        }
    }
}

private struct LoginSettingsSection: View {
    @State private var isEnabled = LoginItem.isEnabled
    @State private var status = LoginItem.statusDescription

    var body: some View {
        Section {
            Toggle("Open at login", isOn: Binding(
                get: { isEnabled },
                set: { newValue in
                    LoginItem.setEnabled(newValue)
                    refresh()
                }
            ))
        } header: {
            Text("Login")
        } footer: {
            Text(status)
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
            Text("Turn off a display to hide its bar.")
        }
        .onReceive(NotificationCenter.default.publisher(
            for: NSApplication.didChangeScreenParametersNotification
        )) { _ in
            displays = Display.connected()
        }
    }
}

private struct PinnedTab: View {
    @ObservedObject var pinned: PinnedAppsStore

    var body: some View {
        if pinned.pins.isEmpty {
            ContentUnavailableView {
                Label("No Pinned Apps", systemImage: "pin.slash")
            } description: {
                Text("Right-click a chip on the bar and choose Pin to Bar, or drag an app from Finder onto the bar.")
            }
        } else {
            Form {
                ForEach(pinned.pins) { app in
                    PinnedAppRow(
                        app: app,
                        isFirst: app == pinned.pins.first,
                        isLast: app == pinned.pins.last,
                        onUp: { pinned.move(app, by: -1) },
                        onDown: { pinned.move(app, by: 1) },
                        onRemove: { pinned.unpin(bundleID: app.bundleID) }
                    )
                }
            }
            .formStyle(.grouped)
            .padding(.horizontal, 12)
        }
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
            Text(app.name)
            Spacer()
            PinnedListIconButton(systemName: "chevron.up", label: "Move Up", disabled: isFirst, action: onUp)
            PinnedListIconButton(systemName: "chevron.down", label: "Move Down", disabled: isLast, action: onDown)
            PinnedListIconButton(systemName: "minus.circle", label: "Unpin from Bar", disabled: false, action: onRemove)
        }
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
            Text("Version \(AppVersion.short) (\(AppVersion.build))")
                .font(.callout)
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
