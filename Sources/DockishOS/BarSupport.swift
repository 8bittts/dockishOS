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
            .background(Capsule().fill(Color.red))
            .overlay(Capsule().stroke(Color.white.opacity(0.45), lineWidth: 0.5))
            .accessibilityLabel("\(text) notifications")
    }
}

/// SwiftUI wrapper around `NSImageView` that displays an app's icon by PID.
/// Cheap to render — `NSRunningApplication` lookup is constant-time.
struct AppIconView: NSViewRepresentable {
    let pid: pid_t

    func makeNSView(context: Context) -> NSImageView {
        let v = NSImageView()
        v.imageScaling = .scaleProportionallyUpOrDown
        return v
    }

    func updateNSView(_ nsView: NSImageView, context: Context) {
        nsView.image = NSRunningApplication(processIdentifier: pid)?.icon
    }
}

/// `NSVisualEffectView` bridge used as the bar's translucent background.
/// `.behindWindow` makes desktop content show through the bar.
struct VisualEffectView: NSViewRepresentable {
    var material: NSVisualEffectView.Material
    var blending: NSVisualEffectView.BlendingMode

    func makeNSView(context: Context) -> NSVisualEffectView {
        let v = NSVisualEffectView()
        v.material = material
        v.blendingMode = blending
        v.state = .active
        return v
    }

    func updateNSView(_ v: NSVisualEffectView, context: Context) {
        v.material = material
        v.blendingMode = blending
    }
}

/// Constants reused across chip components so the look stays consistent.
enum ChipStyle {
    static let cornerRadius: CGFloat = 8
    static let inactiveOpacity: Double = 0.08
    static let hoverOpacity: Double = 0.18
    static let frontmostOpacity: Double = 0.22
    static let hoverLift: CGFloat = 1
    static let hoverScale: CGFloat = 1.012
    static let borderOpacity: Double = 0.05
    static let hoverBorderOpacity: Double = 0.12
    static let frontmostBorderOpacity: Double = 0.10
    static let hoverShadowOpacity: Double = 0.16
    static let hoverShadowRadius: CGFloat = 10
    static let hoverShadowYOffset: CGFloat = 3
    static let topHighlightOpacity: Double = 0.08
    static let hoverTopHighlightOpacity: Double = 0.14
    static let hoverAnimation = Animation.spring(response: 0.20, dampingFraction: 0.84)
}
