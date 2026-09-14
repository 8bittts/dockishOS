/// Non-wrapping index move used by Space switching (scroll and menu).
public enum BoundedIndex {
    /// Returns `current + delta` when that index lies in `0..<count`.
    /// Returns `nil` at the ends, or when `count <= 0`.
    public static func moving(_ current: Int, by delta: Int, count: Int) -> Int? {
        guard count > 0 else { return nil }
        let next = current + delta
        guard (0..<count).contains(next) else { return nil }
        return next
    }
}
