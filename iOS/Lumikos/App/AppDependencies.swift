import Foundation
import SwiftData

/// Everything the screens need, created once. Coordinators pass it on.
/// Simple manual dependency injection: no containers, no singletons.
@MainActor
final class AppDependencies {
    let tokenStore: TokenStore
    let api: APIClient
    let network = NetworkMonitor()
    let flags = FeatureFlags()
    let modelContainer: ModelContainer

    init() {
        let tokenStore = TokenStore()
        self.tokenStore = tokenStore
        api = APIClient(baseURL: Self.serverURL, tokenStore: tokenStore)
        // The local SwiftData database: an offline copy of my list.
        modelContainer = try! ModelContainer(for: CachedItem.self)
    }

    /// Which server to use:
    /// - by default, simulator and iPhone: `APIURL` from Info.plist (set in iOS/Project.swift);
    /// - the API_URL variable, if set: for example `http://localhost:8080` for `mise run api`
    ///   (Xcode → Edit Scheme → Run → Environment Variables). Handy for a quick local test.
    static var serverURL: URL {
        if let custom = ProcessInfo.processInfo.environment["API_URL"], let url = URL(string: custom) {
            return url
        }
        let plistValue = Bundle.main.object(forInfoDictionaryKey: "APIURL") as? String ?? ""
        return URL(string: plistValue)!
    }
}

/// Feature toggles from GET /config. The last answer is saved, so the app knows them offline too.
@MainActor
final class FeatureFlags {
    private(set) var config: AppConfigResponse?

    var ratingsEnabled: Bool { config?.flags["ratings"] ?? true }
    var episodesEnabled: Bool { config?.flags["episodes"] ?? true }

    init() {
        if let data = UserDefaults.standard.data(forKey: "config") {
            config = try? JSONDecoder().decode(AppConfigResponse.self, from: data)
        }
    }

    func refresh(using api: APIClient) async {
        guard let fresh: AppConfigResponse = try? await api.send(.config) else { return }
        config = fresh
        UserDefaults.standard.set(try? JSONEncoder().encode(fresh), forKey: "config")
    }

    /// true when this app is older than the server's minVersion. "1.10.0" > "1.9.0" thanks to .numeric.
    func needsUpdate(appVersion: String) -> Bool {
        guard let min = config?.minVersion else { return false }
        return Self.isVersion(appVersion, olderThan: min)
    }

    static func isVersion(_ version: String, olderThan min: String) -> Bool {
        version.compare(min, options: .numeric) == .orderedAscending
    }
}
