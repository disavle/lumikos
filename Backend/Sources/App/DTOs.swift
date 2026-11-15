import Shared
import Vapor

// The API models live in the Shared package (../Shared), the iOS app uses the same file.
// Here we only teach Vapor about them:
// - Content: Vapor can read them from a request and send them as JSON;
// - Validatable: Vapor checks the fields and answers 400 with a readable reason.
//
// @retroactive: both the protocol (Vapor) and the types (Shared) come from other modules.
// Swift warns about such conformances; the attribute says "yes, I mean it".

extension RegisterRequest: @retroactive Content, @retroactive Validatable {
    public static func validations(_ validations: inout Validations) {
        validations.add("email", as: String.self, is: .email)
        validations.add("nickname", as: String.self, is: .count(3...20) && .characterSet(.alphanumerics + CharacterSet(charactersIn: "_")))
        validations.add("password", as: String.self, is: .count(8...128))
    }
}

extension ListItem: @retroactive Content, @retroactive Validatable {
    // `status` needs no rule: an unknown value already fails to decode into the Status enum.
    public static func validations(_ validations: inout Validations) {
        validations.add("rating", as: Int?.self, is: .nil || .range(1...5), required: false)
    }
}

extension LoginRequest: @retroactive Content {}
extension AuthResponse: @retroactive Content {}
extension Me: @retroactive Content {}
extension TitleCard: @retroactive Content {}
extension FeedPage: @retroactive Content {}
extension TitleDetails: @retroactive Content {}
extension SeasonDetails: @retroactive Content {}

extension ListItem {
    /// Database row → API model.
    init(_ row: ListItemModel) {
        self.init(
            id: row.tmdbID,
            type: MediaType(rawValue: row.mediaType) ?? .movie,
            title: row.title,
            year: row.year,
            posterPath: row.posterPath,
            status: Status(rawValue: row.status) ?? .want,
            pinned: row.pinned,
            rating: row.rating,
            watchedEpisodes: row.watchedEpisodes,
            totalEpisodes: row.totalEpisodes,
            addedAt: row.addedAt ?? Date()
        )
    }
}
