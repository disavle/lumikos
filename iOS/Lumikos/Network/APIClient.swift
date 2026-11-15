import Foundation

/// The whole network layer: build a URLRequest, send it with URLSession, decode JSON.
/// No third-party packages: URLSession + Codable + async/await are enough.
@MainActor
final class APIClient {
    struct ServerError: LocalizedError {
        let status: Int
        let reason: String
        var errorDescription: String? { reason }
    }

    /// Called on 401: the token expired or was removed, the coordinator shows the login screen.
    var onUnauthorized: (() -> Void)?

    private let baseURL: URL
    private let session: URLSession
    private let tokenStore: TokenStore
    private let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()
    private let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()

    init(baseURL: URL, tokenStore: TokenStore, configuration: URLSessionConfiguration = .default) {
        // URLCache keeps answers that the server marks with Cache-Control (episode lists)
        // and posters from AsyncImage. 200 MB on disk is plenty.
        configuration.urlCache = URLCache(memoryCapacity: 20_000_000, diskCapacity: 200_000_000)
        // Render's free server sleeps and needs up to a minute to wake up.
        configuration.timeoutIntervalForRequest = 70
        self.baseURL = baseURL
        self.tokenStore = tokenStore
        self.session = URLSession(configuration: configuration)
    }

    /// Sends a request and decodes the answer into `T`.
    func send<T: Decodable>(_ endpoint: Endpoint, as type: T.Type = T.self) async throws -> T {
        let data = try await perform(endpoint)
        return try decoder.decode(T.self, from: data)
    }

    /// Sends a request when we do not need the answer (logout, delete).
    func send(_ endpoint: Endpoint) async throws {
        _ = try await perform(endpoint)
    }

    private func perform(_ endpoint: Endpoint) async throws -> Data {
        var components = URLComponents(url: baseURL.appending(path: endpoint.path), resolvingAgainstBaseURL: false)!
        if !endpoint.query.isEmpty { components.queryItems = endpoint.query }

        var request = URLRequest(url: components.url!)
        request.httpMethod = endpoint.method
        // The server asks TMDB in this language.
        request.setValue(Locale.preferredLanguages.first ?? "en", forHTTPHeaderField: "Accept-Language")
        if let token = endpoint.explicitToken ?? tokenStore.token {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        if let body = endpoint.body {
            request.httpBody = try encoder.encode(body)
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }

        let (data, response) = try await session.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard (200..<300).contains(status) else {
            if status == 401, tokenStore.token != nil { onUnauthorized?() }
            // Vapor sends errors as {"error": true, "reason": "..."}
            let reason = (try? decoder.decode(VaporError.self, from: data))?.reason
            throw ServerError(status: status, reason: reason ?? HTTPURLResponse.localizedString(forStatusCode: status))
        }
        return data
    }

    private struct VaporError: Decodable {
        let reason: String
    }
}
