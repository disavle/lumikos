import Foundation
import Observation
import Shared

@MainActor
@Observable
final class FeedViewModel {
    /// The first card is on top of the stack.
    private(set) var cards: [TitleCard] = []
    private(set) var isLoading = false
    private(set) var errorMessage: String?

    var onOpenDetails: ((TitleCard) -> Void)?

    private let api: APIClient
    private let loader: FeedLoader
    private var shownKeys = Set<String>()  // so a card never comes back twice

    init(api: APIClient) {
        self.api = api
        self.loader = FeedLoader(api: api)
    }

    func loadIfNeeded() async {
        guard cards.count < 5 else { return }
        isLoading = cards.isEmpty
        errorMessage = nil
        do {
            // A page can be almost empty (everything already seen), so try up to 3 pages.
            for _ in 0..<3 where cards.count < 5 {
                let new = try await loader.nextPage()
                if new.isEmpty { break }
                cards += new.filter { shownKeys.insert($0.key).inserted }
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func reload() async {
        await loader.reset()
        cards = []
        await loadIfNeeded()
    }

    /// Right = add to my list, left = skip (the server remembers it, so it never shows up again).
    func swipe(_ card: TitleCard, liked: Bool) {
        cards.removeAll { $0.key == card.key }
        let item = ListItem(card: card, status: liked ? .want : .skipped)
        Task {
            // If saving fails, the card is gone anyway: a feed is not worth an error alert.
            try? await api.send(.saveItem(item))
            await loadIfNeeded()
        }
    }

    func open(_ card: TitleCard) {
        onOpenDetails?(card)
    }
}
