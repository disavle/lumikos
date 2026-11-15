/// Loads feed pages one by one.
///
/// Why an actor: the user can swipe fast, and two swipes may ask for "the next page" at the same time.
/// An actor runs its methods one at a time, so `page` and `isLoading` never get mixed up.
/// Note the `await` inside: while it waits, another call can enter (actor reentrancy).
/// That second call sees `isLoading == true` and returns at once, so the page is loaded only once.
actor FeedLoader {
    private let api: APIClient
    private var page = 1
    private var hasMore = true
    private var isLoading = false

    init(api: APIClient) {
        self.api = api
    }

    /// The next page of cards, or an empty array if it is already loading or there is nothing more.
    func nextPage() async throws -> [TitleCard] {
        guard hasMore, !isLoading else { return [] }
        isLoading = true
        defer { isLoading = false }

        let result: FeedPage = try await api.send(.feed(page: page))
        page += 1
        hasMore = result.hasMore
        return result.items
    }

    func reset() {
        page = 1
        hasMore = true
    }
}
