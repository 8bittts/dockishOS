/// Round-robin selection for an app's windows. Cycles over a STABLE order (ids
/// sorted ascending) so the choice doesn't reshuffle when raising a window
/// reorders the underlying z-ordered list. Tracking the last-activated id (not a
/// positional index) is what guarantees each call advances to a distinct window.
package enum WindowCycle {
    /// The next window id after `last` in the stable ascending-id cycle.
    /// Returns the first id when `last` is nil or no longer present, and nil
    /// when there are no windows.
    package static func next(ids: [UInt32], after last: UInt32?) -> UInt32? {
        let ordered = ids.sorted()
        guard let first = ordered.first else { return nil }
        guard let last, let index = ordered.firstIndex(of: last) else { return first }
        return ordered[(index + 1) % ordered.count]
    }
}
