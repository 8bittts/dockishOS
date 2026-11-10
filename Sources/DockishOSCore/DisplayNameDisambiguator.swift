/// Suffixes duplicate display names with an incrementing index so colliding
/// screens render distinctly (e.g. "Studio Display 1", "Studio Display 2").
/// Names that are already unique are returned unchanged. Order is preserved.
package enum DisplayNameDisambiguator {
    package struct Item: Equatable {
        package let id: String
        package let name: String

        package init(id: String, name: String) {
            self.id = id
            self.name = name
        }
    }

    package static func disambiguate(_ items: [Item]) -> [Item] {
        let counts = items.reduce(into: [String: Int]()) { $0[$1.name, default: 0] += 1 }
        var seen: [String: Int] = [:]
        return items.map { item in
            guard counts[item.name, default: 0] > 1 else { return item }
            let ordinal = seen[item.name, default: 0] + 1
            seen[item.name] = ordinal
            return Item(id: item.id, name: "\(item.name) \(ordinal)")
        }
    }
}
