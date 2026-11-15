import Fluent
import Vapor

/// Sign up, log in, log out. Email + nickname + password.
struct AuthController: RouteCollection {
    func boot(routes: any RoutesBuilder) throws {
        let auth = routes.grouped("auth")
        auth.post("register", use: register)
        auth.post("login", use: login)
        auth.post("logout", use: logout)
    }

    /// POST /auth/register {email, nickname, password} → {token, user}
    func register(req: Request) async throws -> AuthResponse {
        try RegisterRequest.validate(content: req)  // 400 if the email looks wrong, the password is short, ...
        let body = try req.content.decode(RegisterRequest.self)
        let email = body.email.lowercased()
        let nickname = body.nickname.lowercased()

        let taken = try await User.query(on: req.db)
            .group(.or) { $0.filter(\.$email == email).filter(\.$nickname == nickname) }
            .first()
        if taken != nil {
            throw Abort(.conflict, reason: "This email or nickname is already taken")
        }

        // Bcrypt: slow on purpose and with a random salt, so stolen hashes are hard to crack.
        let hash = try await req.password.async.hash(body.password)
        let user = User(email: email, nickname: nickname, passwordHash: hash)
        try await user.save(on: req.db)
        return try await issueToken(for: user, on: req)
    }

    /// POST /auth/login {login, password} → {token, user}. `login` is the email or the nickname.
    func login(req: Request) async throws -> AuthResponse {
        let body = try req.content.decode(LoginRequest.self)
        let login = body.login.lowercased()
        let user = try await User.query(on: req.db)
            .filter(login.contains("@") ? \.$email : \.$nickname, .equal, login)
            .first()

        // The same answer for "no such user" and "wrong password":
        // otherwise anyone could check which emails are registered.
        guard let user, try await req.password.async.verify(body.password, created: user.passwordHash) else {
            throw Abort(.unauthorized, reason: "Wrong login or password")
        }
        return try await issueToken(for: user, on: req)
    }

    /// POST /auth/logout: forget the current token.
    func logout(req: Request) async throws -> HTTPStatus {
        if let bearer = req.headers.bearerAuthorization {
            try await UserToken.query(on: req.db)
                .filter(\.$tokenHash == UserToken.hash(bearer.token))
                .delete()
        }
        return .noContent
    }

    private func issueToken(for user: User, on req: Request) async throws -> AuthResponse {
        let (plain, token) = try UserToken.generate(for: user)
        try await token.save(on: req.db)
        return AuthResponse(token: plain, user: MeResponse(email: user.email, nickname: user.nickname))
    }
}

/// GET /me and DELETE /me (the App Store requires a way to delete the account).
struct MeController: RouteCollection {
    func boot(routes: any RoutesBuilder) throws {
        routes.get("me") { req async throws -> MeResponse in
            let user = try req.auth.require(User.self)
            return MeResponse(email: user.email, nickname: user.nickname)
        }
        routes.delete("me") { req async throws -> HTTPStatus in
            // Tokens and list items go away too: their foreign keys have `onDelete: .cascade`.
            try await req.auth.require(User.self).delete(on: req.db)
            return .noContent
        }
    }
}

/// GET /config: feature toggles for the app. Public, the app reads it before login.
struct ConfigController: RouteCollection {
    func boot(routes: any RoutesBuilder) throws {
        routes.get("config") { req async throws -> ConfigResponse in
            let flags = try await Flag.query(on: req.db).all()
            return ConfigResponse(
                // Set MIN_VERSION on Render to make old apps ask for an update.
                minVersion: Environment.get("MIN_VERSION") ?? "0.1.0",
                maintenanceMessage: Environment.get("MAINTENANCE_MESSAGE"),
                flags: Dictionary(uniqueKeysWithValues: flags.map { ($0.id ?? "", $0.enabled) })
            )
        }
    }
}
