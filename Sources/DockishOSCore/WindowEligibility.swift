/// Which window-server windows get a chip: the normal-layer, visible windows
/// of regular apps (the apps in the Dock and Command-Tab), never this app's.
/// System agents such as WindowManager own layer-0 windows too, and must not
/// appear on the bar.
package enum WindowEligibility {
    package static func showsChip(
        layer: Int,
        alpha: Double,
        ownerIsRegularApp: Bool,
        ownerIsThisApp: Bool
    ) -> Bool {
        layer == 0 && alpha > 0 && ownerIsRegularApp && !ownerIsThisApp
    }
}
