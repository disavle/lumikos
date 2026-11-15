import Foundation
import Observation

/// Search for movies and series by name, to add them to my list.
@MainActor
@Observable
final class SearchViewModel {
    var query = ""
    private(set) var results: [TitleCard] = []
    private(set) var isSearching = false
    private(set) var errorMessage: String?
    /// Titles added from this screen, so the "+" turns into a checkmark at once.
    private(set) var addedKeys: Set<String> = []

    var onOpenDetails: ((TitleCard) -> Void)?
    var onAdded: (() -> Void)?

    private let api: APIClient

    init(api: APIClient) {
        self.api = api
    }

    /// Called by `.task(id: query)` in the view. Every new letter cancels the previous task,
    /// so the sleep below works as a debounce: we search only when typing stops for 0.4 s.
    func search() async {
        let text = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard text.count >= 2 else {
            results = []
            return
        }
        try? await Task.sleep(for: .milliseconds(400))
        guard !Task.isCancelled else { return }

        isSearching = true
        defer { isSearching = false }
        do {
            let page: FeedPage = try await api.send(.search(query: text))
            results = page.items
            errorMessage = nil
        } catch {
            // A cancelled request is not an error: the user just typed another letter.
            if !Task.isCancelled { errorMessage = error.localizedDescription }
        }
    }

    func add(_ card: TitleCard) async {
        do {
            try await api.send(.saveItem(ListItem(card: card, status: .want)))
            addedKeys.insert(card.key)
            onAdded?()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
