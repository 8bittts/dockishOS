/// Index wrapping for the window switcher's selection.
package enum SelectionWrap {
    /// Advance `index` by `delta` within `0..<count`, wrapping around in both
    /// directions. Returns `index` unchanged when `count <= 0`. Robust for any
    /// `delta` magnitude (including `< -count`).
    package static func advance(_ index: Int, by delta: Int, count: Int) -> Int {
        guard count > 0 else { return index }
        return ((index + delta) % count + count) % count
    }
}
