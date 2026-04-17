import AppKit
import ScreenCaptureKit

/// One-shot window capture via ScreenCaptureKit.
/// Requires Screen Recording permission. Returns nil on any error so the
/// caller can degrade gracefully (e.g. show the window chip without a preview).
enum ThumbnailCapture {
    static func capture(windowID: CGWindowID, maxDimension: CGFloat = 480) async -> NSImage? {
        do {
            let content = try await SCShareableContent.current
            guard let scWindow = content.windows.first(where: { $0.windowID == windowID }) else {
                return nil
            }
            let filter = SCContentFilter(desktopIndependentWindow: scWindow)
            let config = SCStreamConfiguration()
            let scale = min(1.0, maxDimension / max(scWindow.frame.width, scWindow.frame.height))
            config.width = max(64, Int(scWindow.frame.width * scale))
            config.height = max(64, Int(scWindow.frame.height * scale))
            config.scalesToFit = true
            config.showsCursor = false
            config.ignoreShadowsDisplay = true
            let cgImage = try await SCScreenshotManager.captureImage(
                contentFilter: filter,
                configuration: config
            )
            return NSImage(
                cgImage: cgImage,
                size: NSSize(width: cgImage.width, height: cgImage.height)
            )
        } catch {
            return nil
        }
    }
}
