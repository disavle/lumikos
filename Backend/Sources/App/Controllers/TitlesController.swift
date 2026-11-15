import Fluent
import Vapor

/// Data from TMDB: the swipe feed, details, seasons.
struct TitlesController: RouteCollection {
    func boot(routes: any RoutesBuilder) throws {
        routes.get("feed", use: feed)
        routes.get("titles", ":type", ":id", use: details)
        routes.get("titles", "tv", ":id", "seasons", ":season", use: season)
    }

    /// GET /feed?page=1: cards to swipe.
    /// Recommendations for the last 3 titles I added, plus what is trending this week.
    /// Titles already in my list (or skipped) are removed.
    func feed(req: Request) async throws -> FeedPage {
        let user = try req.auth.require(User.self)
        let page = max(req.query[Int.self, at: "page"] ?? 1, 1)
        let tmdb = TMDB(request: req)

        let mine = try await ListItem.query(on: req.db)
            .filter(\.$user.$id == user.requireID())
            .sort(\.$addedAt, .descending)
            .all()
        let seen = Set(mine.map { "\($0.mediaType)-\($0.tmdbID)" })
        let liked = mine.filter { $0.status != "skipped" }.prefix(3)

        // Ask TMDB for all recommendations at the same time, not one after another.
        // A task group runs child tasks in parallel and waits for all of them.
        let recommended = await withTaskGroup(of: [TitleCard].self) { group in
            for item in liked {
                let type = MediaType(rawValue: item.mediaType)
                group.addTask {
                    // One failed request should not break the whole feed, so `try?`.
                    let result: TMDBPage<TMDBItem>? = try? await tmdb.get(
                        "\(item.mediaType)/\(item.tmdbID)/recommendations", page: page)
                    return result?.results.compactMap { TitleCard($0, defaultType: type) } ?? []
                }
            }
            return await group.reduce(into: []) { $0 += $1 }
        }
        let trending: TMDBPage<TMDBItem> = try await tmdb.get("trending/all/week", page: page)

        // Mix, drop duplicates and titles I have already seen.
        var keys = Set<String>()
        let cards = (recommended + trending.results.compactMap { TitleCard($0) }).filter { card in
            let key = "\(card.type.rawValue)-\(card.id)"
            return !seen.contains(key) && keys.insert(key).inserted
        }
        return FeedPage(page: page, hasMore: page < trending.totalPages, items: cards.shuffled())
    }

    /// GET /titles/:type/:id: details plus my list item for this title.
    func details(req: Request) async throws -> Response {
        let user = try req.auth.require(User.self)
        let (type, id) = try titleParameters(req)
        let info: TMDBDetails = try await TMDB(request: req).get("\(type.rawValue)/\(id)")
        let mine = try await ListController().find(type: type, id: id, userID: user.requireID(), on: req.db)

        let details = TitleDetails(
            card: TitleCard(info, type: type),
            backdropPath: info.backdropPath,
            genres: info.genres?.map(\.name) ?? [],
            runtime: info.runtime,
            // Season 0 is "Specials" in TMDB, we skip it to keep things simple.
            seasons: (info.seasons ?? [])
                .filter { $0.seasonNumber > 0 }
                .map { SeasonInfo(number: $0.seasonNumber, name: $0.name, episodeCount: $0.episodeCount) },
            totalEpisodes: info.numberOfEpisodes,
            myItem: mine.map(ListItemDTO.init)
        )
        // Not cached: `myItem` changes whenever I tap a button.
        return try await details.encodeResponse(for: req)
    }

    /// GET /titles/tv/:id/seasons/:season: episodes of one season.
    func season(req: Request) async throws -> Response {
        guard let id = req.parameters.get("id", as: Int.self),
              let number = req.parameters.get("season", as: Int.self)
        else { throw Abort(.badRequest) }
        let info: TMDBSeason = try await TMDB(request: req).get("tv/\(id)/season/\(number)")
        let season = SeasonDetails(
            number: info.seasonNumber,
            episodes: info.episodes.map { Episode(number: $0.episodeNumber, name: $0.name) }
        )
        let response = try await season.encodeResponse(for: req)
        // Episode lists rarely change. URLSession on the phone keeps this answer for 1 hour
        // in its URLCache and does not even send the request again.
        response.headers.replaceOrAdd(name: .cacheControl, value: "private, max-age=3600")
        return response
    }
}
