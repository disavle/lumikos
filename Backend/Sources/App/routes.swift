import Vapor

/// All URLs of the server in one place. Details are in the controllers.
func routes(_ app: Application) throws {
    // Public routes: no login needed.
    app.get("health") { _ in "ok" }
    try app.register(collection: AuthController())

    // Everything below needs `Authorization: Bearer <token>`.
    // TokenAuthenticator finds the user by the token, guardMiddleware answers 401 if there is none.
    let protected = app.grouped(TokenAuthenticator(), User.guardMiddleware())
    try protected.register(collection: MeController())
    try protected.register(collection: TitlesController())
    try protected.register(collection: ListController())
}
