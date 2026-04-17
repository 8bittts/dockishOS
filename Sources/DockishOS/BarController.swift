import AppKit
import SwiftUI

final class BarController {
    private let screen: NSScreen
    private let panel: BarPanel
    private let host: NSHostingView<BarView>

    init(screen: NSScreen) {
        self.screen = screen
        let height: CGFloat = 56
        let visible = screen.visibleFrame
        let frame = NSRect(
            x: visible.minX,
            y: visible.minY,
            width: visible.width,
            height: height
        )
        self.panel = BarPanel(contentRect: frame)
        self.host = NSHostingView(rootView: BarView(store: WindowStore.shared))
        host.autoresizingMask = [.width, .height]
        panel.contentView = host
        panel.setFrame(frame, display: true)
    }

    func show() { panel.orderFrontRegardless() }
    func close() { panel.orderOut(nil); panel.close() }
}
