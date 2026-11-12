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
            .padding(.horizontal, Spacing.xs)
            .padding(.vertical, Spacing.hairline)
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
            .padding(.horizontal, Spacing.xs)
            .padding(.vertical, Spacing.hairline)
            .background(RoundedRectangle(cornerRadius: Radius.mark, style: .continuous).fill(ChipStyle.accent))
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

    /// Take the size SwiftUI proposes. Otherwise the image view keeps its
    /// icon's intrinsic size and draws past the chip's frame and padding.
    func sizeThatFits(_ proposal: ProposedViewSize, nsView: NSImageView, context: Context) -> CGSize? {
        proposal.replacingUnspecifiedDimensions()
    }
}

extension View {
    /// The floating surface behind the bar, the edge tab and the switcher:
    /// Liquid Glass, which brings its own shadow and edge highlights and
    /// adapts to Reduce Transparency. It is never interactive glass, which
    /// stretches the surface under the pointer and changes its shape on a click.
    func floatingSurface(cornerRadius: CGFloat) -> some View {
        glassEffect(.regular, in: .rect(cornerRadius: cornerRadius))
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

/// The one spacing scale for the bar, the edge tab and the switcher: steps
/// of a 4-point grid. Every gap, inset and offset in those views is one of these.
enum Spacing {
    /// Text-tight vertical padding inside a badge only.
    static let hairline: CGFloat = 1
    static let xxs: CGFloat = 2
    static let xs: CGFloat = 4
    static let s: CGFloat = 8
    static let m: CGFloat = 12
    static let xl: CGFloat = 20
}

/// The one motion scale. Every animation in the app is one of these.
enum Motion {
    /// One phase of a bar transition: the slide or fade out, then the one in.
    static let phase: TimeInterval = 0.16
    /// Small feedback: chip hover, switcher scroll.
    static let quick = Animation.easeOut(duration: 0.12)
    /// Chips moving to new places in the row.
    static let reorder = Animation.spring(response: 0.30, dampingFraction: 0.82)
}

/// The one corner scale. The bar itself is square (0).
enum Radius {
    /// Window-count mark.
    static let mark: CGFloat = 4
    /// Chips, chip labels and the edge tab.
    static let control: CGFloat = 8
    /// Switcher tile.
    static let tile: CGFloat = 12
    /// Switcher panel.
    static let panel: CGFloat = 16
}

/// Constants reused across chip components so the look stays consistent.
enum ChipStyle {
    static let hoverFill = Color(nsColor: .selectedContentBackgroundColor).opacity(0.22)
    static let frontmostFill = Color(nsColor: .selectedContentBackgroundColor).opacity(0.34)
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
