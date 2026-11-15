import Foundation
import SwiftData

/// Everything the screens need, created once. Coordinators pass it on.
/// Simple manual dependency injection: no containers, no singletons.
@MainActor
final class AppDependencies {
    let tokenStore: TokenStore
    let api: APIClient
    let network = NetworkMonitor()
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
