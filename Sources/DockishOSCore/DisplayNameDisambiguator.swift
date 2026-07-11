/// Suffixes duplicate display names with an incrementing index so colliding
/// screens render distinctly (e.g. "Studio Display 1", "Studio Display 2").
/// Names that are already unique are returned unchanged. Order is preserved.
public enum DisplayNameDisambiguator {
    public struct Item: Equatable {
        public let id: String
        public let name: String
        public init(id: String, name: String) {
            self.id = id
            self.name = name
        }
    }

    public static func disambiguate(_ items: [Item]) -> [Item] {
        let counts = items.reduce(into: [String: Int]()) { result, item in
            result[item.name, default: 0] += 1
        }
        var seen: [String: Int] = [:]
        return items.map { item in
            guard counts[item.name, default: 0] > 1 else { return item }
            seen[item.name, default: 0] += 1
            return Item(id: item.id, name: "\(item.name) \(seen[item.name]!)")
        }
    }
}
