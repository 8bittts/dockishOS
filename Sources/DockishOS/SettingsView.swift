import SwiftUI
import AppKit
import DockishOSCore

/// The panes of the Settings window, in toolbar order.
enum SettingsPane: CaseIterable {
    case general, bar

    /// Every pane has this width; each is as tall as its content.
    static let width: CGFloat = 480

    var title: String {
        switch self {
        case .general: return "General"
        case .bar:     return "Bar"
        }
    }

    var symbolName: String {
        switch self {
        case .general: return "gearshape"
        case .bar:     return "dock.rectangle"
        }
    }
}

/// One Settings pane, sized to its content so the window fits each pane.
struct SettingsPaneView: View {
    let pane: SettingsPane

    var body: some View {
        Group {
            switch pane {
            case .general: GeneralPane(settings: .shared, pinned: .shared)
            case .bar:     BarPane(settings: .shared)
            }
        }
        .formStyle(.grouped)
        .frame(width: SettingsPane.width)
        .fixedSize(horizontal: false, vertical: true)
    }
}

// MARK: - General

private struct GeneralPane: View {
    @ObservedObject var settings: SettingsStore
    let pinned: PinnedAppsStore

    var body: some View {
        Form {
            LoginSection()
            ShortcutSection(hotkey: $settings.switcherHotkey)
            PinnedSection(pinned: pinned)
            DisplaysSection(settings: settings)
            AccessibilitySection()
        }
    }
}

private struct LoginSection: View {
    @State private var isEnabled = LoginItem.isEnabled
    @State private var note = LoginItem.statusNote

    var body: some View {
        Section {
            Toggle("Open at login", isOn: Binding(
                get: { isEnabled },
                set: { newValue in
                    LoginItem.setEnabled(newValue)
                    refresh()
                }
            ))
        } footer: {
            if let note {
                Text(note)
            }
        }
        .onAppear(perform: refresh)
    }

    /// Reads the state back from the system: registering can fail or wait
    /// for the user's approval.
    private func refresh() {
        isEnabled = LoginItem.isEnabled
        note = LoginItem.statusNote
    }
}

private struct ShortcutSection: View {
    @Binding var hotkey: Hotkey

    var body: some View {
        Section {
            LabeledContent("App switcher") {
                if hotkey != .switcherDefault {
                    Button("Reset") { hotkey = .switcherDefault }
                        .accessibilityLabel("Reset app switcher shortcut")
                }
                HotkeyRecorder(title: "App switcher shortcut", hotkey: $hotkey)
            }
        } footer: {
            Text("Click the shortcut, then press a new one with Control, Option, or Command. Esc cancels.")
        }
    }
}

/// One toggle per display. Hidden with a single display, where the only
/// toggle could not be turned off.
private struct DisplaysSection: View {
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
        Group {
            if displays.count > 1 {
                Section("Show the Bar On") {
                    ForEach(displays) { display in
                        Toggle(display.name, isOn: Binding(
                            get: { !settings.disabledScreenUUIDs.contains(display.id) },
                            set: { settings.setScreen(display.id, enabled: $0) }
                        ))
                    }
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(
            for: NSApplication.didChangeScreenParametersNotification
        )) { _ in
            displays = Display.connected()
        }
    }
}

/// The Accessibility permission: its state, or the button that asks for it.
/// Rechecks when the app becomes active, which is when the user comes back
/// from System Settings.
private struct AccessibilitySection: View {
    @State private var isGranted = Permissions.isAccessibilityGranted

    var body: some View {
        Section {
            LabeledContent("Accessibility") {
                if isGranted {
                    Text("Granted")
                } else {
                    Button("Grant Access…") { Permissions.requestAccessibilityFromSettings() }
                }
            }
        } footer: {
            Text("Lets DockishOS raise or close one window, and read Dock badges.")
        }
        .onAppear(perform: refresh)
        .onReceive(NotificationCenter.default.publisher(
            for: NSApplication.didBecomeActiveNotification
        )) { _ in
            refresh()
        }
    }

    private func refresh() {
        isGranted = Permissions.isAccessibilityGranted
    }
}

// MARK: - Bar

private struct BarPane: View {
    @ObservedObject var settings: SettingsStore

    var body: some View {
        Form {
            Section("Layout") {
                Picker("Size", selection: $settings.barSize) {
                    ForEach(BarSize.allCases) { Text($0.displayName).tag($0) }
                }
                .pickerStyle(.segmented)

                Picker("Position", selection: $settings.barPosition) {
                    ForEach(BarPosition.allCases) { Text($0.displayName).tag($0) }
                }
                .pickerStyle(.segmented)
            }

            Section {
                Toggle("Show window titles", isOn: $settings.showChipTitles)
                Toggle("Group windows by app", isOn: $settings.groupWindowsByApp)
                Toggle("Show pinned apps", isOn: $settings.showPinnedRow)
                Toggle("Show notification badges", isOn: $settings.showNotificationBadges)
            } header: {
                Text("Contents")
            } footer: {
                Text("Badges come from the Dock and need Accessibility. A future macOS release can stop them from working.")
            }

            Section("Edge Tab") {
                Toggle("Collapse bar into edge tab", isOn: $settings.barCollapsed)

                Picker("Corner", selection: $settings.collapsedTabPosition) {
                    ForEach(CollapsedTabPosition.allCases) { Text($0.displayName).tag($0) }
                }
                .pickerStyle(.segmented)
            }
        }
    }
}

// MARK: - Pinned apps

/// The pinned apps, in bar order. Stays one section when the list is empty,
/// so the pane sizes the same way either way.
private struct PinnedSection: View {
    @ObservedObject var pinned: PinnedAppsStore

    var body: some View {
        Section {
            if pinned.pins.isEmpty {
                Text("No pinned apps")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(pinned.pins) { app in
                    PinnedAppRow(
                        app: app,
                        isFirst: app == pinned.pins.first,
                        isLast: app == pinned.pins.last,
                        onMove: { pinned.move(app, by: $0) },
                        onUnpin: { pinned.unpin(bundleID: app.bundleID) }
                    )
                }
            }
        } header: {
            Text("Pinned Apps")
        } footer: {
            Text("Right-click a chip on the bar and choose Pin to Bar, or drag an app from Finder onto the bar.")
        }
    }
}

private struct PinnedAppRow: View {
    let app: PinnedApp
    let isFirst: Bool
    let isLast: Bool
    /// Moves the app by the given offset: -1 is up, +1 is down.
    let onMove: (Int) -> Void
    let onUnpin: () -> Void

    var body: some View {
        LabeledContent {
            iconButton("chevron.up", label: "Move Up") { onMove(-1) }
                .disabled(isFirst)
            iconButton("chevron.down", label: "Move Down") { onMove(1) }
                .disabled(isLast)
            iconButton("minus.circle", label: "Unpin from Bar", action: onUnpin)
        } label: {
            Label {
                Text(app.name)
            } icon: {
                Image(nsImage: NSWorkspace.shared.icon(forFile: app.path))
                    .resizable()
                    .frame(width: 20, height: 20)
            }
        }
    }

    /// Borderless symbol button with the 20-point minimum hit target.
    private func iconButton(_ systemName: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .frame(width: 20, height: 20)
                .contentShape(Rectangle())
        }
        .buttonStyle(.borderless)
        .help(label)
        .accessibilityLabel(label)
    }
}
