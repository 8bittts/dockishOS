/// Screen corner that holds the collapsed bar's edge tab.
package enum CollapsedTabPosition: String, CaseIterable, Identifiable, Sendable {
    case bottomLeft
    case bottomRight

    package var id: String { rawValue }

    package var isRightEdge: Bool { self == .bottomRight }
}
