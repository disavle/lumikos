import Vapor

// What the server sends and receives. The iOS app has the same structs in Network/Models.swift.
// JSON keys are camelCase, dates are ISO 8601.

enum MediaType: String, Content, CaseIterable {
    case movie, tv
}

// MARK: - Auth

struct RegisterRequest: Content, Validatable {
    let email: String
    let nickname: String
    let password: String

    // Vapor checks these rules with `RegisterRequest.validate(content: req)` and answers 400 with a readable reason.
    static func validations(_ validations: inout Validations) {
        validations.add("email", as: String.self, is: .email)
        validations.add("nickname", as: String.self, is: .count(3...20) && .characterSet(.alphanumerics + CharacterSet(charactersIn: "_")))
        validations.add("password", as: String.self, is: .count(8...128))
    }
}

struct LoginRequest: Content {
    let login: String  // email or nickname
    let password: String
}

struct AuthResponse: Content {
    let token: String
    let user: MeResponse
}

struct MeResponse: Content {
    let email: String
    let nickname: String
}

// MARK: - Config

struct ConfigResponse: Content {
    let minVersion: String
    let maintenanceMessage: String?
    let flags: [String: Bool]
}

// MARK: - Titles

/// A short card: for the swipe feed and for lists.
struct TitleCard: Content {
    let id: Int
    let type: MediaType
    let title: String
    let year: Int?
    let posterPath: String?
    let overview: String?
    let voteAverage: Double?
}

struct FeedPage: Content {
    let page: Int
    let hasMore: Bool
    let items: [TitleCard]
}

struct TitleDetails: Content {
    let card: TitleCard
    let backdropPath: String?
    let genres: [String]
    let runtime: Int?            // minutes, movies only
    let seasons: [SeasonInfo]    // empty for movies
    let totalEpisodes: Int?
    let myItem: ListItemDTO?     // this title in my list, if it is there
}

struct SeasonInfo: Content {
    let number: Int
    let name: String
    let episodeCount: Int
}

struct SeasonDetails: Content {
    let number: Int
    let episodes: [Episode]
}

struct Episode: Content {
    let number: Int
    let name: String
}

// MARK: - My list

struct ListItemDTO: Content {
    let id: Int
    let type: MediaType
    let title: String
    let year: Int?
    let posterPath: String?
    let status: String
    let pinned: Bool
    let rating: Int?
    let watchedEpisodes: [String]
    let totalEpisodes: Int?
    let addedAt: Date
}

/// Body of `PUT /list/:type/:id`. The app always sends the whole item, the server overwrites it.
struct ListItemUpdate: Content, Validatable {
    let title: String
    let year: Int?
    let posterPath: String?
    let status: String
    let pinned: Bool
    let rating: Int?
    let watchedEpisodes: [String]
    let totalEpisodes: Int?

    static func validations(_ validations: inout Validations) {
        validations.add("status", as: String.self, is: .in("want", "watched", "skipped"))
        validations.add("rating", as: Int?.self, is: .nil || .range(1...5), required: false)
    }
}

extension ListItemDTO {
    init(_ item: ListItem) {
        self.init(
            id: item.tmdbID,
            type: MediaType(rawValue: item.mediaType) ?? .movie,
            title: item.title,
            year: item.year,
            posterPath: item.posterPath,
            status: item.status,
            pinned: item.pinned,
            rating: item.rating,
            watchedEpisodes: item.watchedEpisodes,
            totalEpisodes: item.totalEpisodes,
            addedAt: item.addedAt ?? Date()
        )
    }
}
