import Foundation

// The JSON contract between the app and the server, in one place.
// Change a field here and both sides see it at compile time.
// JSON keys are camelCase, dates are ISO 8601.
//
// Types from another module must be `public`, and structs need a `public init`:
// Swift does not make the memberwise init public by itself.

public enum MediaType: String, Codable, Sendable, Hashable, CaseIterable {
    case movie, tv
}

// MARK: - Auth

public struct RegisterRequest: Codable, Sendable {
    public let email: String
    public let nickname: String
    public let password: String

    public init(email: String, nickname: String, password: String) {
        self.email = email
        self.nickname = nickname
        self.password = password
    }
}

public struct LoginRequest: Codable, Sendable {
    public let login: String  // email or nickname
    public let password: String

    public init(login: String, password: String) {
        self.login = login
        self.password = password
    }
}

public struct AuthResponse: Codable, Sendable {
    public let token: String
    public let user: Me

    public init(token: String, user: Me) {
        self.token = token
        self.user = user
    }
}

public struct Me: Codable, Sendable {
    public let email: String
    public let nickname: String

    public init(email: String, nickname: String) {
        self.email = email
        self.nickname = nickname
    }
}

// MARK: - Titles

/// A short card: for the swipe feed, search and lists.
public struct TitleCard: Codable, Sendable, Hashable, Identifiable {
    public let id: Int
    public let type: MediaType
    public let title: String
    public let year: Int?
    public let posterPath: String?
    public let overview: String?
    public let voteAverage: Double?

    public init(id: Int, type: MediaType, title: String, year: Int?, posterPath: String?, overview: String?, voteAverage: Double?) {
        self.id = id
        self.type = type
        self.title = title
        self.year = year
        self.posterPath = posterPath
        self.overview = overview
        self.voteAverage = voteAverage
    }

    /// Movie 603 and series 603 are different titles, so the key has both.
    public var key: String { "\(type.rawValue)-\(id)" }
}

public struct FeedPage: Codable, Sendable {
    public let page: Int
    public let hasMore: Bool
    public let items: [TitleCard]

    public init(page: Int, hasMore: Bool, items: [TitleCard]) {
        self.page = page
        self.hasMore = hasMore
        self.items = items
    }
}

public struct TitleDetails: Codable, Sendable {
    public let card: TitleCard
    public let backdropPath: String?
    public let genres: [String]
    public let runtime: Int?            // minutes, movies only
    public let seasons: [SeasonInfo]    // empty for movies
    public let totalEpisodes: Int?
    public let myItem: ListItem?        // this title in my list, if it is there

    public init(card: TitleCard, backdropPath: String?, genres: [String], runtime: Int?,
                seasons: [SeasonInfo], totalEpisodes: Int?, myItem: ListItem?) {
        self.card = card
        self.backdropPath = backdropPath
        self.genres = genres
        self.runtime = runtime
        self.seasons = seasons
        self.totalEpisodes = totalEpisodes
        self.myItem = myItem
    }
}

public struct SeasonInfo: Codable, Sendable, Hashable, Identifiable {
    public let number: Int
    public let name: String
    public let episodeCount: Int
    public var id: Int { number }

    public init(number: Int, name: String, episodeCount: Int) {
        self.number = number
        self.name = name
        self.episodeCount = episodeCount
    }
}

public struct SeasonDetails: Codable, Sendable {
    public let number: Int
    public let episodes: [Episode]

    public init(number: Int, episodes: [Episode]) {
        self.number = number
        self.episodes = episodes
    }
}

public struct Episode: Codable, Sendable, Hashable, Identifiable {
    public let number: Int
    public let name: String
    public var id: Int { number }

    public init(number: Int, name: String) {
        self.number = number
        self.name = name
    }
}

// MARK: - My list

/// A title in my list. The app changes a copy and sends the whole thing back with `PUT /list/:type/:id`.
public struct ListItem: Codable, Sendable, Hashable, Identifiable {
    public enum Status: String, Codable, Sendable {
        case want, watched, skipped
    }

    public let id: Int
    public let type: MediaType
    public var title: String
    public var year: Int?
    public var posterPath: String?
    public var status: Status
    public var pinned: Bool
    public var rating: Int?               // 1...5, shown as emoji
    public var watchedEpisodes: [String]  // ["S1E1", "S1E2"]
    public var totalEpisodes: Int?
    public var addedAt: Date

    public init(id: Int, type: MediaType, title: String, year: Int?, posterPath: String?, status: Status,
                pinned: Bool, rating: Int?, watchedEpisodes: [String], totalEpisodes: Int?, addedAt: Date) {
        self.id = id
        self.type = type
        self.title = title
        self.year = year
        self.posterPath = posterPath
        self.status = status
        self.pinned = pinned
        self.rating = rating
        self.watchedEpisodes = watchedEpisodes
        self.totalEpisodes = totalEpisodes
        self.addedAt = addedAt
    }

    /// A new item made from a card (feed, search or details).
    public init(card: TitleCard, status: Status) {
        self.init(id: card.id, type: card.type, title: card.title, year: card.year, posterPath: card.posterPath,
                  status: status, pinned: false, rating: nil, watchedEpisodes: [], totalEpisodes: nil, addedAt: .now)
    }

    public var key: String { "\(type.rawValue)-\(id)" }

    /// "S1E3" is the format the server stores.
    public static func episodeKey(season: Int, episode: Int) -> String { "S\(season)E\(episode)" }
}
