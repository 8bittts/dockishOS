import XCTest

final class HIGChromeRegressionTests: XCTestCase {
    func testAppIconGeneratorDoesNotBakeASquircle() throws {
        let source = try RepositorySource.read("scripts/generate-app-icon.swift")
        XCTAssertTrue(
            source.contains("Full-bleed square"),
            "The icon generator must document that the asset is an unmasked square."
        )
        XCTAssertFalse(
            source.contains("addClip()"),
            "The icon generator must not clip the mark to a baked squircle."
        )
    }

    func testSettingsWindowOmitsMiniaturizeAndZoom() throws {
        let source = try RepositorySource.read("Sources/DockishOS/SettingsController.swift")
        XCTAssertTrue(
            source.contains("styleMask: [.titled, .closable]"),
            "Settings must not offer miniaturize or zoom."
        )
        XCTAssertFalse(
            source.contains(".miniaturizable"),
            "Settings must not be miniaturizable."
        )
    }

    /// The floating surfaces are the system's Liquid Glass, and nothing
    /// rebuilds glass or a material by hand.
    func testFloatingSurfaceIsSystemGlass() throws {
        let support = try RepositorySource.read("Sources/DockishOS/BarSupport.swift")
        XCTAssertTrue(support.contains("glassEffect("), "The floating surface must use glassEffect.")
        for path in ["BarView.swift", "CollapsedBarTab.swift", "SwitcherView.swift"] {
            let source = try RepositorySource.read("Sources/DockishOS/\(path)")
            XCTAssertTrue(source.contains(".floatingSurface("), "\(path) must use the shared floating surface.")
        }
        for name in try RepositorySource.appSourceNames() {
            let source = try RepositorySource.read("Sources/DockishOS/\(name)")
            XCTAssertFalse(source.contains("NSVisualEffectView"), "\(name) must not fall back to a visual effect view.")
            XCTAssertFalse(source.contains("LinearGradient"), "\(name) must not draw its own highlights.")
            XCTAssertFalse(source.contains("#available"), "\(name) must not branch on a macOS version below the minimum.")
        }
    }

    /// The bar is a square strip that fills its panel, which spans the
    /// screen's width and rests on its edge, so no desktop shows around it.
    func testExpandedBarSurfaceIsSquareAndFillsThePanel() throws {
        let source = try RepositorySource.read("Sources/DockishOS/BarView.swift")
        XCTAssertTrue(source.contains(".floatingSurface(cornerRadius: 0)"), "The bar must not round its corners.")
        XCTAssertFalse(source.contains(".padding(.vertical"), "The bar surface must not be inset from the panel.")
        XCTAssertFalse(source.contains("RoundedRectangle"), "The bar and its drop ring must be square.")
    }

    /// The bar, edge tab and switcher take every gap and corner from the
    /// one `Spacing` and `Radius` scale, so no view drifts to its own number.
    func testBarViewsUseTheSharedSpacingAndRadiusScale() throws {
        let literal = try NSRegularExpression(
            pattern: #"(padding\((\.\w+, )?|spacing: |offset\(x: -?|y: -?|cornerRadius: )[1-9][0-9.]*"#
        )
        let views = ["BarView", "WindowChips", "PinnedRow", "CollapsedBarTab", "SwitcherView"]
        for name in views {
            let source = try RepositorySource.read("Sources/DockishOS/\(name).swift")
            let range = NSRange(source.startIndex..., in: source)
            let hits = literal.matches(in: source, range: range).compactMap { Range($0.range, in: source) }
            XCTAssertEqual(hits.map { String(source[$0]) }, [], "\(name).swift must use Spacing and Radius.")
        }
        let support = try RepositorySource.read("Sources/DockishOS/BarSupport.swift")
        XCTAssertFalse(support.contains(".interactive("), "Interactive glass changes the edge tab's shape on a click.")
    }

    /// Every animation takes its timing from the one `Motion` scale.
    func testAnimationsUseTheSharedMotionScale() throws {
        for name in try RepositorySource.appSourceNames() where name != "BarSupport.swift" {
            let source = try RepositorySource.read("Sources/DockishOS/\(name)")
            for literal in ["duration: 0", "duration = 0", ".spring(", ".easeOut(duration", ".easeInOut(duration"] {
                XCTAssertFalse(source.contains(literal), "\(name) must use Motion, not \(literal).")
            }
        }
    }

    /// Size, position and corner move the existing bars. Closing and
    /// reopening every panel on each change is the flicker this guards.
    func testLayoutChangesMoveBarsInsteadOfRebuildingThem() throws {
        let source = try RepositorySource.read("Sources/DockishOS/AppDelegate.swift")
        XCTAssertTrue(source.contains("observeOnMain(.dockishBarLayoutDidChange) { [weak self] _ in self?.applyLayoutChange() }"))
        XCTAssertTrue(source.contains("bars.forEach { $0.followSettings() }"))
    }

    /// HIG Menus: represent actions consistently, so no two status menu
    /// commands share an icon.
    func testStatusMenuIconsAreDistinct() throws {
        let source = try RepositorySource.read("Sources/DockishOS/MenuBarController.swift")
        let pattern = try NSRegularExpression(pattern: #"(?:symbol: |Symbol = )"([a-z.]+)""#)
        let symbols = pattern.matches(in: source, range: NSRange(source.startIndex..., in: source)).compactMap {
            Range($0.range(at: 1), in: source).map { String(source[$0]) }
        }
        XCTAssertGreaterThan(symbols.count, 5, "The scan must find the menu's symbols.")
        XCTAssertEqual(symbols.count, Set(symbols).count, "Duplicate menu icons: \(symbols)")
    }

    /// HIG Settings: restore the most recently viewed pane.
    func testSettingsWindowRestoresTheLastPane() throws {
        let source = try RepositorySource.read("Sources/DockishOS/SettingsController.swift")
        XCTAssertTrue(source.contains("UserDefaults.standard.set(selectedTabViewItemIndex, forKey: Self.selectedPaneKey)"))
        // The restore must run after the panes are added, not in viewDidLoad,
        // which runs while the controller still has no panes.
        let added = try XCTUnwrap(source.range(of: "panes.addTabViewItem(item)"))
        let restored = try XCTUnwrap(source.range(of: "panes.restoreLastPane()"))
        XCTAssertLessThan(added.lowerBound, restored.lowerBound)
        XCTAssertFalse(source.contains("override func viewDidLoad"))
    }

    /// The app supports macOS 27 only, the one release its design is checked
    /// on. Every place that declares the minimum must agree, or Sparkle
    /// offers the update to a Mac that cannot run it.
    func testMinimumSystemVersionIsMacOS27Everywhere() throws {
        XCTAssertTrue(try RepositorySource.read("Package.swift").contains("platforms: [.macOS(.v27)]"))
        XCTAssertTrue(
            try RepositorySource.read("Resources/Info.plist")
                .contains("<key>LSMinimumSystemVersion</key>\n\t<string>27.0</string>"),
            "Sparkle's generate_appcast reads the appcast's minimum system version from this key."
        )
    }

    /// Settings is a standard toolbar of panes: each pane is a grouped form
    /// as tall as its content, with no margins or sizes of its own.
    func testSettingsPanesAreNativeAndSizeToContent() throws {
        let controller = try RepositorySource.read("Sources/DockishOS/SettingsController.swift")
        XCTAssertTrue(controller.contains("tabStyle = .toolbar"))
        XCTAssertTrue(controller.contains("sizingOptions = .preferredContentSize"), "The window must follow each pane's height.")
        let panes = try RepositorySource.read("Sources/DockishOS/SettingsView.swift")
        XCTAssertTrue(panes.contains(".fixedSize(horizontal: false, vertical: true)"))
        XCTAssertFalse(panes.contains(".padding(.horizontal"), "A pane uses the form's own margins.")
        XCTAssertFalse(panes.contains("\"About\""), "About is the standard About panel, not a Settings pane.")
    }

    func testNotificationBadgeUsesSystemRed() throws {
        let source = try RepositorySource.read("Sources/DockishOS/BarSupport.swift")
        XCTAssertTrue(
            source.contains("Color(nsColor: .systemRed)"),
            "Notification badges must use systemRed."
        )
        XCTAssertFalse(
            source.contains("Capsule().fill(Color.red)"),
            "Notification badges must not use hardcoded Color.red."
        )
    }
}
