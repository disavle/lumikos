import Foundation
import Observation
import Shared

@MainActor
@Observable
final class DetailsViewModel {
    let card: TitleCard
    private(set) var details: TitleDetails?
    /// This title in my list, `nil` if it is not there.
    private(set) var item: ListItem?
    /// Loaded seasons: season number → episodes. Loaded only when a season is opened.
    private(set) var episodes: [Int: [Episode]] = [:]
    private(set) var errorMessage: String?

    var onChange: ((ListItem?) -> Void)?

    private let api: APIClient

    init(card: TitleCard, api: APIClient) {
        self.card = card
        self.api = api
    }

    var isInList: Bool { item != nil && item?.status != .skipped }

    func load() async {
        do {
            let details: TitleDetails = try await api.send(.details(card.type, id: card.id))
            self.details = details
            item = details.myItem
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func loadEpisodes(season: Int) async {
        guard episodes[season] == nil else { return }
        // URLCache keeps this answer for an hour (the server sends Cache-Control), so opening again is instant.
        if let result: SeasonDetails = try? await api.send(.season(tvID: card.id, number: season)) {
            episodes[season] = result.episodes
        }
    }

    // MARK: - Buttons. Each one changes a copy of the item and saves it.

    func addToList() async { await update { $0.status = .want } }
    func markWatched() async { await update { $0.status = $0.status == .watched ? .want : .watched } }
    func togglePin() async { await update { $0.pinned.toggle() } }
    func setRating(_ rating: Int?) async { await update { $0.rating = rating } }

    func isWatched(season: Int, episode: Int) -> Bool {
        item?.watchedEpisodes.contains(ListItem.episodeKey(season: season, episode: episode)) ?? false
    }

    func toggleEpisode(season: Int, episode: Int) async {
        let key = ListItem.episodeKey(season: season, episode: episode)
        await update { item in
            if let index = item.watchedEpisodes.firstIndex(of: key) {
                item.watchedEpisodes.remove(at: index)
            } else {
                item.watchedEpisodes.append(key)
            }
        }
    }

    /// Marks every episode of the season (or unmarks them if all are already marked).
    func toggleSeason(_ season: SeasonInfo) async {
        let keys = (1...max(season.episodeCount, 1)).map { ListItem.episodeKey(season: season.number, episode: $0) }
        await update { item in
            let allWatched = keys.allSatisfy { item.watchedEpisodes.contains($0) }
            item.watchedEpisodes.removeAll { keys.contains($0) }
            if !allWatched { item.watchedEpisodes += keys }
        }
    }

    func remove() async {
        do {
            try await api.send(.deleteItem(card.type, id: card.id))
            item = nil
            onChange?(nil)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Takes the current item (or a new one), lets `change` edit it, sends it with PUT.
    private func update(_ change: (inout ListItem) -> Void) async {
        var changed = item ?? ListItem(card: card, status: .want)
        if changed.status == .skipped { changed.status = .want }
        changed.totalEpisodes = details?.totalEpisodes
        change(&changed)
        do {
            let saved: ListItem = try await api.send(.saveItem(changed))
            item = saved
            errorMessage = nil
            onChange?(saved)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
