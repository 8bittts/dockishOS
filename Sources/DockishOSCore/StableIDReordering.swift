import Foundation

package enum StableIDReordering {
    package static func moving<T: Identifiable>(
        _ items: [T],
        itemID: T.ID,
        by delta: Int
    ) -> [T] where T.ID: Equatable {
        guard let sourceIndex = items.firstIndex(where: { $0.id == itemID }) else { return items }
        let destinationIndex = sourceIndex + delta
        guard items.indices.contains(destinationIndex) else { return items }

        var next = items
        next.swapAt(sourceIndex, destinationIndex)
        return next
    }

    package static func moving<T: Identifiable>(
        _ items: [T],
        sourceID: T.ID,
        onto targetID: T.ID
    ) -> [T] where T.ID: Equatable {
        guard sourceID != targetID else { return items }
        guard let sourceIndex = items.firstIndex(where: { $0.id == sourceID }) else { return items }

        var next = items
        let item = next.remove(at: sourceIndex)
        if let targetIndex = next.firstIndex(where: { $0.id == targetID }) {
            next.insert(item, at: targetIndex)
        } else {
            next.append(item)
        }
        return next
    }
}
