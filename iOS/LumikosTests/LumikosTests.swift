import Foundation
import Testing

@testable import Lumikos

// Swift Testing: @Test functions and #expect instead of XCTestCase and XCTAssert.

@Suite("My list")
struct ListArrangeTests {
    private func item(_ id: Int, _ type: MediaType, pinned: Bool = false, rating: Int? = nil, daysAgo: Double) -> ListItem {
        var item = ListItem(
            card: TitleCard(id: id, type: type, title: "Title \(id)", year: nil, posterPath: nil, overview: nil, voteAverage: nil),
            status: .want
        )
        item.pinned = pinned
        item.rating = rating
        item.addedAt = Date(timeIntervalSinceNow: -daysAgo * 86_400)
        return item
    }

    @Test("Pinned titles go to their own section, newest first")
    func pinnedOnTop() {
        let items = [item(1, .movie, daysAgo: 3), item(2, .tv, pinned: true, daysAgo: 2), item(3, .movie, daysAgo: 1)]
        let result = ListViewModel.arrange(items, filter: .all, sort: .added)
        #expect(result.pinned.map(\.id) == [2])
        #expect(result.rest.map(\.id) == [3, 1])
    }

    @Test("Filter by type", arguments: [
        (ListViewModel.Filter.movies, [3, 1]),
        (ListViewModel.Filter.series, [2]),
    ])
    func filter(filter: ListViewModel.Filter, expected: [Int]) {
        let items = [item(1, .movie, daysAgo: 3), item(2, .tv, daysAgo: 2), item(3, .movie, daysAgo: 1)]
        #expect(ListViewModel.arrange(items, filter: filter, sort: .added).rest.map(\.id) == expected)
    }

    @Test("Sort by my rating")
    func sortByRating() {
        let items = [item(1, .movie, rating: 2, daysAgo: 1), item(2, .movie, rating: 5, daysAgo: 2), item(3, .movie, daysAgo: 3)]
        #expect(ListViewModel.arrange(items, filter: .all, sort: .rating).rest.map(\.id) == [2, 1, 3])
    }
}

@Suite("Feature flags")
@MainActor
struct FeatureFlagsTests {
    // As text "1.10.0" < "1.9.0", as version numbers it is the other way round.
    @Test("Versions are compared as numbers, not as text", arguments: [
        ("1.9.0", "1.10.0", true),
        ("1.10.0", "1.9.0", false),
        ("1.0.0", "1.0.0", false),
    ])
    func versionCompare(version: String, min: String, older: Bool) {
        #expect(FeatureFlags.isVersion(version, olderThan: min) == older)
    }
}

@Suite("JSON from the server")
struct DecodingTests {
    @Test("A list item decodes with an ISO 8601 date")
    func decodeListItem() throws {
        let json = """
        {"id": 1399, "type": "tv", "title": "Game of Thrones", "year": 2011, "posterPath": "/a.jpg",
         "status": "watched", "pinned": true, "rating": 4, "watchedEpisodes": ["S1E1"],
         "totalEpisodes": 73, "addedAt": "2026-11-15T10:00:00Z"}
        """
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let item = try decoder.decode(ListItem.self, from: Data(json.utf8))
        #expect(item.type == .tv)
        #expect(item.status == .watched)
        #expect(item.watchedEpisodes == ["S1E1"])
    }
}
