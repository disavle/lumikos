import Testing
import VaporTesting

@testable import App

// Server tests: a real app with an in-memory SQLite database, TMDB is not called.
// Run: `swift test` in the Backend folder.
@Suite("Lumikos server", .serialized)
struct AppTests {
    @Test("Health check answers ok")
    func health() async throws {
        try await withApp { app in
            try await app.testing().test(.GET, "health") { res async in
                #expect(res.status == .ok)
                #expect(res.body.string == "ok")
            }
        }
    }

    @Test("Config returns the seeded flags")
    func config() async throws {
        try await withApp { app in
            try await app.testing().test(.GET, "config") { res async throws in
                let config = try res.content.decode(ConfigResponse.self)
                #expect(config.flags["ratings"] == true)
            }
        }
    }

    @Test("Sign up, then log in with the nickname and see /me")
    func registerLoginMe() async throws {
        try await withApp { app in
            _ = try await register(app)
            let token = try await login(app, as: "Movie_Fan", password: "secret-123")

            try await app.testing().test(.GET, "me", headers: bearer(token)) { res async throws in
                #expect(res.status == .ok)
                let me = try res.content.decode(MeResponse.self)
                #expect(me.nickname == "movie_fan")
                #expect(me.email == "fan@example.com")
            }
        }
    }

    @Test("Wrong password and unknown user get the same 401")
    func wrongPassword() async throws {
        try await withApp { app in
            _ = try await register(app)
            for login in ["movie_fan", "nobody"] {
                try await app.testing().test(.POST, "auth/login", beforeRequest: { req in
                    try req.content.encode(LoginRequest(login: login, password: "wrong-password"))
                }, afterResponse: { res async in
                    #expect(res.status == .unauthorized)
                })
            }
        }
    }

    @Test("A short password is rejected")
    func shortPassword() async throws {
        try await withApp { app in
            try await app.testing().test(.POST, "auth/register", beforeRequest: { req in
                try req.content.encode(RegisterRequest(email: "a@example.com", nickname: "abc", password: "123"))
            }, afterResponse: { res async in
                #expect(res.status == .badRequest)
            })
        }
    }

    @Test("The token is stored only as a hash")
    func tokenIsHashed() async throws {
        try await withApp { app in
            let token = try await register(app)
            let stored = try #require(try await UserToken.query(on: app.db).first())
            #expect(stored.tokenHash != token)
            #expect(stored.tokenHash == UserToken.hash(token))
        }
    }

    @Test("Add a series to the list, mark an episode, log out")
    func listFlow() async throws {
        try await withApp { app in
            let token = try await register(app)
            let update = ListItemUpdate(
                title: "Dark", year: 2017, posterPath: nil, status: "want", pinned: true,
                rating: 5, watchedEpisodes: ["S1E1"], totalEpisodes: 26
            )
            try await app.testing().test(.PUT, "list/tv/70523", headers: bearer(token), beforeRequest: { req in
                try req.content.encode(update)
            }, afterResponse: { res async in
                #expect(res.status == .ok)
            })

            try await app.testing().test(.GET, "list", headers: bearer(token)) { res async throws in
                let items = try res.content.decode([ListItemDTO].self)
                #expect(items.count == 1)
                #expect(items.first?.watchedEpisodes == ["S1E1"])
                #expect(items.first?.pinned == true)
            }

            // After logout the same token does not work any more.
            try await app.testing().test(.POST, "auth/logout", headers: bearer(token)) { _ async in }
            try await app.testing().test(.GET, "list", headers: bearer(token)) { res async in
                #expect(res.status == .unauthorized)
            }
        }
    }

    @Test("An empty search answers at once, without asking TMDB")
    func emptySearch() async throws {
        try await withApp { app in
            let token = try await register(app)
            try await app.testing().test(.GET, "search?q=%20", headers: bearer(token)) { res async throws in
                #expect(res.status == .ok)
                #expect(try res.content.decode(FeedPage.self).items.isEmpty)
            }
        }
    }

    @Test("Series details and seasons have routes (no 404)")
    func seriesRoutes() async throws {
        try await withApp { app in
            let token = try await register(app)
            // There is no TMDB token in tests, so the server answers 500 "TMDB_TOKEN is not set".
            // That is fine here: we only check that the route exists.
            for path in ["titles/tv/1399", "titles/tv/1399/seasons/1", "titles/movie/603"] {
                try await app.testing().test(.GET, path, headers: bearer(token)) { res async in
                    #expect(res.status != .notFound, "\(path)")
                }
            }
        }
    }

    // MARK: - Helpers

    private func withApp(_ test: (Application) async throws -> Void) async throws {
        let app = try await Application.make(.testing)
        do {
            try await configure(app)
            try await test(app)
        } catch {
            try await app.asyncShutdown()
            throw error
        }
        try await app.asyncShutdown()
    }

    /// Signs up fan@example.com / Movie_Fan and returns the token.
    private func register(_ app: Application) async throws -> String {
        let response = try await app.testing().sendRequest(.POST, "auth/register", beforeRequest: { req in
            try req.content.encode(RegisterRequest(email: "Fan@Example.com", nickname: "Movie_Fan", password: "secret-123"))
        })
        #expect(response.status == .ok)
        return try response.content.decode(AuthResponse.self).token
    }

    private func login(_ app: Application, as login: String, password: String) async throws -> String {
        let response = try await app.testing().sendRequest(.POST, "auth/login", beforeRequest: { req in
            try req.content.encode(LoginRequest(login: login, password: password))
        })
        #expect(response.status == .ok)
        return try response.content.decode(AuthResponse.self).token
    }

    private func bearer(_ token: String) -> HTTPHeaders {
        var headers = HTTPHeaders()
        headers.bearerAuthorization = BearerAuthorization(token: token)
        return headers
    }
}
