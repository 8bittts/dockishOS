import SwiftUI
import AppKit

/// Small red capsule rendered over an app icon when the app has a Dock
/// notification badge. Mirrors the appearance of the macOS Dock badge.
struct NotificationBadge: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 9, weight: .bold, design: .rounded))
            .foregroundStyle(.white)
            .padding(.horizontal, 4)
            .padding(.vertical, 1)
            .background(Capsule().fill(Color(nsColor: .systemRed)))
            .overlay(Capsule().stroke(Color(nsColor: .separatorColor).opacity(0.65), lineWidth: 0.5))
            .accessibilityHidden(true)
    }
}

/// Window count uses a rounded square so it stays distinct from the
/// capsule notification badge when both appear on a grouped chip.
struct WindowCountMark: View {
    let count: Int

    var body: some View {
        Text("\(count)")
            .font(.system(size: 9, weight: .bold, design: .monospaced))
            .foregroundStyle(.white)
            .padding(.horizontal, 4)
            .padding(.vertical, 1)
            .background(RoundedRectangle(cornerRadius: 3, style: .continuous).fill(ChipStyle.accent))
            .accessibilityHidden(true)
    }
}

/// SwiftUI wrapper around `NSImageView` that displays an app's icon by PID.
/// Cheap to render — `NSRunningApplication` lookup is constant-time.
struct AppIconView: NSViewRepresentable {
    let pid: pid_t

    func makeNSView(context: Context) -> NSImageView {
        let view = NSImageView()
        view.imageScaling = .scaleProportionallyUpOrDown
        return view
    }

    func updateNSView(_ view: NSImageView, context: Context) {
        view.image = NSRunningApplication(processIdentifier: pid)?.icon
    }
}

/// `NSVisualEffectView` bridge used as the translucent background of the bar,
/// launcher and switcher. Switches to an opaque window material while Reduce
/// Transparency (`accessibilityReduceTransparency`) is on.
struct VisualEffectView: NSViewRepresentable {
    var material: NSVisualEffectView.Material
    var blending: NSVisualEffectView.BlendingMode
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.state = .active
        return view
    }

    func updateNSView(_ view: NSVisualEffectView, context: Context) {
        view.material = reduceTransparency ? .windowBackground : material
        view.blendingMode = reduceTransparency ? .withinWindow : blending
    }
}

/// Constants reused across chip components so the look stays consistent.
enum ChipStyle {
    static let cornerRadius: CGFloat = 8
    /// Inset of the highlighted label pill inside a chip.
    static let labelHorizontalPadding: CGFloat = 7
    static let labelVerticalPadding: CGFloat = 3
    static let hoverBorderOpacity: Double = 0.12
    static let frontmostBorderOpacity: Double = 0.10
    static let topHighlightOpacity: Double = 0.08
    static let hoverTopHighlightOpacity: Double = 0.14
    static let hoverAnimation = Animation.easeOut(duration: 0.10)
    static let hoverFill = Color(nsColor: .selectedContentBackgroundColor).opacity(0.22)
    static let frontmostFill = Color(nsColor: .selectedContentBackgroundColor).opacity(0.34)
    static let border = Color(nsColor: .separatorColor)
    static let accent = Color(nsColor: .controlAccentColor)
}

/// What VoiceOver reads for a chip: the name, then each state that applies.
enum ChipAccessibility {
    static func label(_ name: String, windowCount: Int? = nil, state: String? = nil, badge: String?) -> String {
        var parts = [name]
        if let windowCount { parts.append(windowCountText(windowCount)) }
        if let state { parts.append(state) }
        if let badge { parts.append(badge == "1" ? "1 notification" : "\(badge) notifications") }
        return parts.joined(separator: ", ")
    }

    static func windowCountText(_ count: Int) -> String {
        count == 1 ? "1 window" : "\(count) windows"
    }
}
