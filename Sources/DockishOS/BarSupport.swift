import SwiftUI
import AppKit

/// Small red capsule rendered over an app icon when the app has a Dock
/// notification badge. Mirrors the appearance of the macOS Dock badge.
struct NotificationBadge: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(.caption2, design: .rounded, weight: .bold))
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
            .font(.system(.caption2, design: .monospaced, weight: .bold))
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

extension View {
    /// The floating surface behind the bar, the edge tab and the switcher:
    /// Liquid Glass on macOS 26 and later, and the HUD material before that.
    /// Pass `interactive` for a surface that is itself a control.
    @ViewBuilder
    func floatingSurface(cornerRadius: CGFloat, interactive: Bool = false) -> some View {
        if #available(macOS 26, *) {
            glassEffect(.regular.interactive(interactive), in: .rect(cornerRadius: cornerRadius))
        } else {
            background(
                HUDMaterial()
                    .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
                    .shadow(color: .black.opacity(0.35), radius: 18, y: 6)
            )
        }
    }
}

/// The HUD material for macOS releases before Liquid Glass. Switches to an
/// opaque window material while Reduce Transparency
/// (`accessibilityReduceTransparency`) is on; Liquid Glass adapts by itself.
private struct HUDMaterial: NSViewRepresentable {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.state = .active
        return view
    }

    func updateNSView(_ view: NSVisualEffectView, context: Context) {
        view.material = reduceTransparency ? .windowBackground : .hudWindow
        view.blendingMode = reduceTransparency ? .withinWindow : .behindWindow
    }
}

extension BarSize {
    /// Text style of a chip's title, one step per bar size.
    var chipTitleFont: Font {
        switch self {
        case .small:  return .subheadline
        case .medium: return .body
        case .large:  return .title2
        }
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
