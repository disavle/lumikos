import Crypto
import Fluent
import Vapor

/// A registered person. The password is never stored, only its Bcrypt hash.
final class User: Model, Authenticatable, @unchecked Sendable {
    static let schema = "users"

    @ID(key: .id) var id: UUID?
    @Field(key: "email") var email: String          // lowercased
    @Field(key: "nickname") var nickname: String    // lowercased, so "Dima" and "dima" are the same
    @Field(key: "password_hash") var passwordHash: String
    @Timestamp(key: "created_at", on: .create) var createdAt: Date?

    init() {}

    init(email: String, nickname: String, passwordHash: String) {
        self.email = email
        self.nickname = nickname
        self.passwordHash = passwordHash
    }
}

/// A login session. The app keeps the token itself, the database keeps only its SHA-256 hash.
/// So a copy of the database is useless for logging in.
final class UserToken: Model, @unchecked Sendable {
    static let schema = "user_tokens"

    @ID(key: .id) var id: UUID?
    @Field(key: "token_hash") var tokenHash: String
    @Field(key: "expires_at") var expiresAt: Date
    @Parent(key: "user_id") var user: User

    init() {}

    init(tokenHash: String, userID: UUID, expiresAt: Date) {
        self.tokenHash = tokenHash
        self.$user.id = userID
        self.expiresAt = expiresAt
    }

    /// Creates a random token for the user. Returns the plain token (for the app) and the model (for the database).
    static func generate(for user: User) throws -> (plain: String, model: UserToken) {
        // 32 random bytes are impossible to guess.
        let plain = Data([UInt8].random(count: 32)).base64EncodedString()
        let model = UserToken(
            tokenHash: hash(plain),
            userID: try user.requireID(),
            expiresAt: Date().addingTimeInterval(60 * 60 * 24 * 30)  // 30 days
        )
        return (plain, model)
    }

    static func hash(_ token: String) -> String {
        SHA256.hash(data: Data(token.utf8)).hex
    }
}

/// Reads `Authorization: Bearer <token>` and logs the user in for this request.
/// If the token is unknown or expired, it does nothing, and `User.guardMiddleware()` answers 401.
struct TokenAuthenticator: AsyncBearerAuthenticator {
    func authenticate(bearer: BearerAuthorization, for request: Request) async throws {
        let token = try await UserToken.query(on: request.db)
            .filter(\.$tokenHash == UserToken.hash(bearer.token))
            .with(\.$user)
            .first()
        guard let token, token.expiresAt > Date() else { return }
        request.auth.login(token.user)
    }
}

struct CreateUser: AsyncMigration {
    func prepare(on database: any Database) async throws {
        try await database.schema(User.schema)
            .id()
            .field("email", .string, .required)
            .field("nickname", .string, .required)
            .field("password_hash", .string, .required)
            .field("created_at", .datetime)
            .unique(on: "email")
            .unique(on: "nickname")
            .create()
    }

    func revert(on database: any Database) async throws {
        try await database.schema(User.schema).delete()
    }
}

struct CreateUserToken: AsyncMigration {
    func prepare(on database: any Database) async throws {
        try await database.schema(UserToken.schema)
            .id()
            .field("token_hash", .string, .required)
            .field("expires_at", .datetime, .required)
            // Deleting a user deletes their tokens too.
            .field("user_id", .uuid, .required, .references(User.schema, "id", onDelete: .cascade))
            .unique(on: "token_hash")
            .create()
    }

    func revert(on database: any Database) async throws {
        try await database.schema(UserToken.schema).delete()
    }
}
