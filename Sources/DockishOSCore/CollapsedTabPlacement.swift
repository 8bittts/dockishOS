public enum CollapsedTabPlacement: String, CaseIterable, Codable, Identifiable, Sendable {
    case bottomLeft
    case bottomRight

    public var id: String { rawValue }

    public init(persistedRawValue: String?) {
        switch persistedRawValue {
        case Self.bottomLeft.rawValue?, "topLeft"?:
            self = .bottomLeft
        case Self.bottomRight.rawValue?, "topRight"?:
            self = .bottomRight
        default:
            self = .bottomRight
        }
    }
}
