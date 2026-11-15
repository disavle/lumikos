import Vapor

/// A tiny client for The Movie Database API (https://developer.themoviedb.org/reference).
/// Only the server knows the TMDB token, the app never sees it.
struct TMDB {
    let request: Request

    /// TMDB answers in the user's language: "ru-RU" if the phone is in Russian, otherwise "en-US".
    var language: String {
        let header = request.headers.first(name: .acceptLanguage) ?? ""
        return header.lowercased().hasPrefix("ru") ? "ru-RU" : "en-US"
    }

    func get<T: Decodable>(_ path: String, page: Int? = nil) async throws -> T {
        guard let token = Environment.get("TMDB_TOKEN") else {
            throw Abort(.internalServerError, reason: "TMDB_TOKEN is not set")
        }
        let response = try await request.client.get(URI(string: "https://api.themoviedb.org/3/\(path)")) { req in
            req.headers.bearerAuthorization = BearerAuthorization(token: token)
            var query = ["language": language]
            if let page { query["page"] = String(page) }
            try req.query.encode(query)
        }
        guard response.status == .ok else {
            request.logger.warning("TMDB \(path) answered \(response.status.code)")
            throw Abort(.badGateway, reason: "TMDB is not available")
        }
        // TMDB uses snake_case keys: poster_path → posterPath
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try response.content.decode(T.self, using: decoder)
    }
}

// MARK: - TMDB JSON (only the fields we use)

struct TMDBPage<Item: Decodable>: Decodable {
    let page: Int
    let totalPages: Int
    let results: [Item]
}

/// A result of trending or recommendations. Movies have `title`, series have `name`.
struct TMDBItem: Decodable {
    let id: Int
    let mediaType: String?
    let title: String?
    let name: String?
    let posterPath: String?
    let overview: String?
    let releaseDate: String?
    let firstAirDate: String?
    let voteAverage: Double?
}

struct TMDBDetails: Decodable {
    struct Genre: Decodable { let name: String }
    struct Season: Decodable {
        let seasonNumber: Int
        let name: String
        let episodeCount: Int
    }

    let id: Int
    let title: String?
    let name: String?
    let posterPath: String?
    let backdropPath: String?
    let overview: String?
    let releaseDate: String?
    let firstAirDate: String?
    let voteAverage: Double?
    let genres: [Genre]?
    let runtime: Int?
    let numberOfEpisodes: Int?
    let seasons: [Season]?
}

struct TMDBSeason: Decodable {
    struct Episode: Decodable {
        let episodeNumber: Int
        let name: String
    }
    let seasonNumber: Int
    let episodes: [Episode]
}

// MARK: - TMDB → our DTOs

/// "2024-05-17" → 2024
private func parseYear(_ date: String?) -> Int? {
    date.flatMap { Int($0.prefix(4)) }
}

extension TitleCard {
    /// `nil` for people and unknown types: the feed shows only movies and series.
    init?(_ item: TMDBItem, defaultType: MediaType? = nil) {
        guard let type = item.mediaType.flatMap(MediaType.init(rawValue:)) ?? defaultType,
              let title = item.title ?? item.name
        else { return nil }
        self.init(
            id: item.id,
            type: type,
            title: title,
            year: parseYear(item.releaseDate ?? item.firstAirDate),
            posterPath: item.posterPath,
            overview: item.overview,
            voteAverage: item.voteAverage
        )
    }

    init(_ details: TMDBDetails, type: MediaType) {
        self.init(
            id: details.id,
            type: type,
            title: details.title ?? details.name ?? "",
            year: parseYear(details.releaseDate ?? details.firstAirDate),
            posterPath: details.posterPath,
            overview: details.overview,
            voteAverage: details.voteAverage
        )
    }
}
