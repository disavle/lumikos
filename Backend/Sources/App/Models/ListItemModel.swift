import Fluent
import Vapor

/// One movie or series in a user's list: a row of the `list_items` table.
/// Named ListItemModel, because `ListItem` is the API model from Shared.
/// We copy title, year and poster from TMDB, so the list loads without asking TMDB again.
final class ListItemModel: Model, @unchecked Sendable {
    static let schema = "list_items"

    @ID(key: .id) var id: UUID?
    @Parent(key: "user_id") var user: User
    @Field(key: "tmdb_id") var tmdbID: Int
    @Field(key: "media_type") var mediaType: String       // "movie" or "tv"
    @Field(key: "title") var title: String
    @OptionalField(key: "year") var year: Int?
    @OptionalField(key: "poster_path") var posterPath: String?
    @Field(key: "status") var status: String              // "want", "watched" or "skipped"
    @Field(key: "pinned") var pinned: Bool                // "Watching now"
    @OptionalField(key: "rating") var rating: Int?        // 1...5, shown as emoji
    @Field(key: "watched_episodes") var watchedEpisodes: [String]  // ["S1E1", "S1E2"]
    @OptionalField(key: "total_episodes") var totalEpisodes: Int?
    @Timestamp(key: "added_at", on: .create) var addedAt: Date?
    @Timestamp(key: "updated_at", on: .update) var updatedAt: Date?

    init() {}
}

struct CreateListItem: AsyncMigration {
    func prepare(on database: any Database) async throws {
        try await database.schema(ListItemModel.schema)
            .id()
            .field("user_id", .uuid, .required, .references(User.schema, "id", onDelete: .cascade))
            .field("tmdb_id", .int, .required)
            .field("media_type", .string, .required)
            .field("title", .string, .required)
            .field("year", .int)
            .field("poster_path", .string)
            .field("status", .string, .required)
            .field("pinned", .bool, .required)
            .field("rating", .int)
            .field("watched_episodes", .array(of: .string), .required)
            .field("total_episodes", .int)
            .field("added_at", .datetime)
            .field("updated_at", .datetime)
            // One row per title per user
            .unique(on: "user_id", "media_type", "tmdb_id")
            .create()
    }

    func revert(on database: any Database) async throws {
        try await database.schema(ListItemModel.schema).delete()
    }
}
