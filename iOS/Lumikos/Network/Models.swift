import Foundation

// The same JSON as the server's Backend/Sources/App/DTOs.swift.
// If you change a field there, change it here too.

enum MediaType: String, Codable, Sendable, Hashable {
    case movie, tv
}

struct AuthResponse: Decodable, Sendable {
    let token: String
    let user: Me
}

struct Me: Codable, Sendable {
    let email: String
    let nickname: String
}

struct AppConfigResponse: Codable, Sendable {
    let minVersion: String
    let maintenanceMessage: String?
    let flags: [String: Bool]
}

/// A short card: what the swipe feed shows.
struct TitleCard: Codable, Sendable, Hashable, Identifiable {
    let id: Int
    let type: MediaType
    let title: String
    let year: Int?
    let posterPath: String?
    let overview: String?
    let voteAverage: Double?

    /// Movie 603 and series 603 are different titles, so the key has both.
    var key: String { "\(type.rawValue)-\(id)" }
}

struct FeedPage: Decodable, Sendable {
    let page: Int
    let hasMore: Bool
    let items: [TitleCard]
}

struct TitleDetails: Decodable, Sendable {
    let card: TitleCard
    let backdropPath: String?
    let genres: [String]
    let runtime: Int?
    let seasons: [SeasonInfo]
    let totalEpisodes: Int?
    let myItem: ListItem?
}

struct SeasonInfo: Decodable, Sendable, Hashable, Identifiable {
    let number: Int
    let name: String
    let episodeCount: Int
    var id: Int { number }
}

struct SeasonDetails: Decodable, Sendable {
    let number: Int
    let episodes: [Episode]
}

struct Episode: Decodable, Sendable, Hashable, Identifiable {
    let number: Int
    let name: String
    var id: Int { number }
}

/// A title in my list. The app changes a copy and sends the whole thing back with PUT.
struct ListItem: Codable, Sendable, Hashable, Identifiable {
    enum Status: String, Codable, Sendable {
        case want, watched, skipped
    }

    let id: Int
    let type: MediaType
    var title: String
    var year: Int?
    var posterPath: String?
    var status: Status
    var pinned: Bool
    var rating: Int?
    var watchedEpisodes: [String]
    var totalEpisodes: Int?
    var addedAt: Date

    var key: String { "\(type.rawValue)-\(id)" }

    /// A new item made from a feed card.
    init(card: TitleCard, status: Status) {
        id = card.id
        type = card.type
        title = card.title
        year = card.year
        posterPath = card.posterPath
        self.status = status
        pinned = false
        rating = nil
        watchedEpisodes = []
        totalEpisodes = nil
        addedAt = .now
    }

    /// "S1E3" is the format the server stores.
    static func episodeKey(season: Int, episode: Int) -> String { "S\(season)E\(episode)" }
}
