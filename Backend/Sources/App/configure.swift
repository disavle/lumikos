import Fluent
import FluentPostgresDriver
import FluentSQLiteDriver
import Vapor

/// Sets up the database, JSON, migrations and routes.
public func configure(_ app: Application) async throws {
    // Database:
    // - tests: SQLite in memory;
    // - DATABASE_URL is set (Render): Postgres on Neon;
    // - otherwise (your Mac): a db.sqlite file.
    if app.environment == .testing {
        app.databases.use(.sqlite(.memory), as: .sqlite)
        // Bcrypt is slow on purpose (that is what makes it safe); tests do not need that.
        app.passwords.use(.plaintext)
    } else if let databaseURL = Environment.get("DATABASE_URL") {
        // `?sslmode=require` in the URL turns on TLS, Neon asks for it.
        let postgres = try SQLPostgresConfiguration(url: databaseURL)
        app.databases.use(.postgres(configuration: postgres), as: .psql)
    } else {
        app.databases.use(.sqlite(.file("db.sqlite")), as: .sqlite)
    }

    // Render tells the app which port to listen on.
    if let port = Environment.get("PORT").flatMap(Int.init) {
        app.http.server.configuration.port = port
    }

    // Dates in JSON are ISO 8601 strings, the iOS client decodes them the same way.
    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    ContentConfiguration.global.use(encoder: encoder, for: .json)
    ContentConfiguration.global.use(decoder: decoder, for: .json)

    app.migrations.add(CreateUser())
    app.migrations.add(CreateUserToken())
    app.migrations.add(CreateListItem())

    // Create tables on start: always on your Mac and in tests,
    // and on Render, where the Dockerfile sets AUTO_MIGRATE=true.
    if app.environment != .production || Environment.get("AUTO_MIGRATE") == "true" {
        try await app.autoMigrate()
    }

    try routes(app)
}
