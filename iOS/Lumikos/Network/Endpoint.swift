import Foundation

/// Every request the app makes, in one enum. Adding a request = adding a case here.
enum Endpoint: Sendable {
    case config
    case register(email: String, nickname: String, password: String)
    case login(login: String, password: String)
    case logout(token: String)
    case deleteAccount
    case feed(page: Int)
    case search(query: String)
    case details(MediaType, id: Int)
    case season(tvID: Int, number: Int)
    case list
    case saveItem(ListItem)
    case deleteItem(MediaType, id: Int)

    var method: String {
        switch self {
        case .config, .feed, .search, .details, .season, .list: "GET"
        case .register, .login, .logout: "POST"
        case .saveItem: "PUT"
        case .deleteAccount, .deleteItem: "DELETE"
        }
    }

    var path: String {
        switch self {
        case .config: "config"
        case .register: "auth/register"
        case .login: "auth/login"
        case .logout: "auth/logout"
        case .deleteAccount: "me"
        case .feed: "feed"
        case .search: "search"
        case let .details(type, id): "titles/\(type.rawValue)/\(id)"
        case let .season(tvID, number): "titles/tv/\(tvID)/seasons/\(number)"
        case .list: "list"
        case let .saveItem(item): "list/\(item.type.rawValue)/\(item.id)"
        case let .deleteItem(type, id): "list/\(type.rawValue)/\(id)"
        }
    }

    /// Most requests use the saved token; logout brings its own.
    var explicitToken: String? {
        if case let .logout(token) = self { token } else { nil }
    }

    var query: [URLQueryItem] {
        switch self {
        case let .feed(page): [URLQueryItem(name: "page", value: String(page))]
        case let .search(text): [URLQueryItem(name: "q", value: text)]
        default: []
        }
    }

    /// JSON body for POST and PUT.
    var body: (any Encodable & Sendable)? {
        switch self {
        case let .register(email, nickname, password):
            ["email": email, "nickname": nickname, "password": password]
        case let .login(login, password):
            ["login": login, "password": password]
        case let .saveItem(item):
            item
        default:
            nil
        }
    }
}
