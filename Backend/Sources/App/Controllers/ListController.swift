import Fluent
import Vapor

/// My list: everything I added, watched or skipped.
struct ListController: RouteCollection {
    func boot(routes: any RoutesBuilder) throws {
        let list = routes.grouped("list")
        list.get(use: index)
        list.put(":type", ":id", use: upsert)
        list.delete(":type", ":id", use: remove)
    }

    /// GET /list: the list without skipped titles, newest first. The app sorts it further.
    func index(req: Request) async throws -> [ListItemDTO] {
        let user = try req.auth.require(User.self)
        return try await ListItem.query(on: req.db)
            .filter(\.$user.$id == user.requireID())
            .filter(\.$status != "skipped")
            .sort(\.$addedAt, .descending)
            .all()
            .map(ListItemDTO.init)
    }

    /// PUT /list/:type/:id: add a title or overwrite it. Calling it twice is safe.
    func upsert(req: Request) async throws -> ListItemDTO {
        let user = try req.auth.require(User.self)
        let (type, id) = try titleParameters(req)
        try ListItemUpdate.validate(content: req)
        let body = try req.content.decode(ListItemUpdate.self)

        let item = try await find(type: type, id: id, userID: user.requireID(), on: req.db) ?? ListItem()
        item.$user.id = try user.requireID()
        item.tmdbID = id
        item.mediaType = type.rawValue
        item.title = body.title
        item.year = body.year
        item.posterPath = body.posterPath
        item.status = body.status
        item.pinned = body.pinned
        item.rating = body.rating
        item.watchedEpisodes = body.watchedEpisodes
        item.totalEpisodes = body.totalEpisodes
        try await item.save(on: req.db)
        return ListItemDTO(item)
    }

    /// DELETE /list/:type/:id
    func remove(req: Request) async throws -> HTTPStatus {
        let user = try req.auth.require(User.self)
        let (type, id) = try titleParameters(req)
        try await find(type: type, id: id, userID: user.requireID(), on: req.db)?.delete(on: req.db)
        return .noContent
    }

    func find(type: MediaType, id: Int, userID: UUID, on db: any Database) async throws -> ListItem? {
        try await ListItem.query(on: db)
            .filter(\.$user.$id == userID)
            .filter(\.$mediaType == type.rawValue)
            .filter(\.$tmdbID == id)
            .first()
    }
}

/// Reads `:type` and `:id` from the URL, for example /list/tv/1399.
func titleParameters(_ req: Request) throws -> (MediaType, Int) {
    guard let type = req.parameters.get("type").flatMap(MediaType.init(rawValue:)),
          let id = req.parameters.get("id", as: Int.self)
    else { throw Abort(.badRequest, reason: "Expected /movie/<id> or /tv/<id>") }
    return (type, id)
}
