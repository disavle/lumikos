import Fluent
import Vapor

/// A feature toggle. Change it in the Neon SQL editor, no new app release needed:
///     UPDATE flags SET enabled = false WHERE key = 'ratings';
final class Flag: Model, @unchecked Sendable {
    static let schema = "flags"

    // The key itself is the id, for example "ratings".
    @ID(custom: "key", generatedBy: .user) var id: String?
    @Field(key: "enabled") var enabled: Bool

    init() {}

    init(key: String, enabled: Bool) {
        self.id = key
        self.enabled = enabled
    }
}

struct CreateFlag: AsyncMigration {
    func prepare(on database: any Database) async throws {
        try await database.schema(Flag.schema)
            .field("key", .string, .identifier(auto: false))
            .field("enabled", .bool, .required)
            .create()

        // Starting values. The app knows these keys.
        try await [
            Flag(key: "ratings", enabled: true),   // emoji rating on the details screen
            Flag(key: "episodes", enabled: true),  // episode checkmarks for series
        ].create(on: database)
    }

    func revert(on database: any Database) async throws {
        try await database.schema(Flag.schema).delete()
    }
}
