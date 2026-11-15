import Foundation
import SwiftData

/// SwiftData copy of one list item, so the list opens without internet.
/// The server is the source of truth: after every load we replace the whole copy.
@Model
final class CachedItem {
    @Attribute(.unique) var key: String
    var data: Data  // the ListItem as JSON: one field instead of copying all eleven

    init(_ item: ListItem) throws {
        key = item.key
        data = try JSONEncoder().encode(item)
    }

    var item: ListItem? { try? JSONDecoder().decode(ListItem.self, from: data) }
}

/// Reads and writes the offline copy.
@MainActor
struct ListCache {
    let context: ModelContext

    func load() -> [ListItem] {
        let rows = (try? context.fetch(FetchDescriptor<CachedItem>())) ?? []
        return rows.compactMap(\.item)
    }

    func replace(with items: [ListItem]) {
        try? context.delete(model: CachedItem.self)
        for item in items {
            if let row = try? CachedItem(item) { context.insert(row) }
        }
        try? context.save()
    }
}
