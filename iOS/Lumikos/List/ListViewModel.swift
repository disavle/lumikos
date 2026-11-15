import Combine
import Foundation
import Observation

@MainActor
@Observable
final class ListViewModel {
    enum Filter: String, CaseIterable, Identifiable {
        case all, movies, series
        var id: Self { self }
    }

    enum Sort: String, CaseIterable, Identifiable {
        case added, rating, title
        var id: Self { self }
    }

    var filter: Filter = .all
    var sort: Sort = .added
    private(set) var items: [ListItem] = []
    private(set) var isOnline = true
    private(set) var errorMessage: String?
    let nickname: String

    var onOpenDetails: ((ListItem) -> Void)?
    var onLogOut: (() -> Void)?

    private let api: APIClient
    private let cache: ListCache
    private let network: NetworkMonitor
    @ObservationIgnored private var networkSubscription: AnyCancellable?

    init(api: APIClient, cache: ListCache, network: NetworkMonitor, nickname: String) {
        self.api = api
        self.cache = cache
        self.network = network
        self.nickname = nickname
        items = cache.load()  // show the saved copy at once, then refresh
        observeNetwork()
    }

    /// "Watching now" on top, everything else below.
    var sections: (pinned: [ListItem], rest: [ListItem]) {
        Self.arrange(items, filter: filter, sort: sort)
    }

    /// A pure function: easy to test, see LumikosTests.
    static func arrange(_ items: [ListItem], filter: Filter, sort: Sort) -> (pinned: [ListItem], rest: [ListItem]) {
        let filtered = items.filter { item in
            switch filter {
            case .all: true
            case .movies: item.type == .movie
            case .series: item.type == .tv
            }
        }
        let sorted = filtered.sorted { a, b in
            switch sort {
            case .added: a.addedAt > b.addedAt
            case .rating: (a.rating ?? 0) > (b.rating ?? 0)
            case .title: a.title.localizedCompare(b.title) == .orderedAscending
            }
        }
        return (sorted.filter(\.pinned), sorted.filter { !$0.pinned })
    }

    func refresh() async {
        do {
            let fresh: [ListItem] = try await api.send(.list)
            items = fresh
            cache.replace(with: fresh)
            errorMessage = nil
        } catch {
            // Offline: keep showing the cached copy.
            if network.isOnlineNow { errorMessage = error.localizedDescription }
        }
    }

    /// Combine: subscribe to the publisher with `sink`. The subscription lives while we keep the AnyCancellable.
    /// `receive(on:)` moves values to the main thread; `assumeIsolated` tells the compiler we are on it.
    private func observeNetwork() {
        networkSubscription = network.isOnline
            .dropFirst()  // the first value is the current state, nothing changed yet
            .receive(on: DispatchQueue.main)
            .sink { [weak self] online in
                MainActor.assumeIsolated {
                    guard let self else { return }
                    self.isOnline = online
                    if online { Task { await self.refresh() } }  // back online: load fresh data
                }
            }
        isOnline = network.isOnlineNow
    }

    func togglePin(_ item: ListItem) async {
        var changed = item
        changed.pinned.toggle()
        await save(changed)
    }

    func delete(_ item: ListItem) async {
        let backup = items
        items.removeAll { $0.key == item.key }  // optimistic: remove at once, put back on error
        do {
            try await api.send(.deleteItem(item.type, id: item.id))
            cache.replace(with: items)
        } catch {
            items = backup
            errorMessage = error.localizedDescription
        }
    }

    func logOut() {
        onLogOut?()
    }

    func deleteAccount() async {
        do {
            try await api.send(.deleteAccount)
            cache.replace(with: [])
            onLogOut?()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func save(_ item: ListItem) async {
        do {
            let saved: ListItem = try await api.send(.saveItem(item))
            if let index = items.firstIndex(where: { $0.key == saved.key }) { items[index] = saved }
            cache.replace(with: items)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
