import Foundation
import Observation
import Shared

/// Login and sign up in one screen. `mode` switches between them.
@MainActor
@Observable
final class AuthViewModel {
    enum Mode { case login, register }

    var mode: Mode = .login
    var email = ""
    var nickname = ""
    var login = ""      // email or nickname
    var password = ""
    private(set) var isLoading = false
    private(set) var errorMessage: String?

    /// The coordinator listens to this and shows the tabs.
    var onLoggedIn: (() -> Void)?

    private let api: APIClient
    private let tokenStore: TokenStore

    init(api: APIClient, tokenStore: TokenStore) {
        self.api = api
        self.tokenStore = tokenStore
    }

    var canSubmit: Bool {
        switch mode {
        case .login: !login.isEmpty && !password.isEmpty && !isLoading
        case .register: email.contains("@") && nickname.count >= 3 && password.count >= 8 && !isLoading
        }
    }

    func submit() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let endpoint: Endpoint = switch mode {
            case .login: .login(login: login.trimmed, password: password)
            case .register: .register(email: email.trimmed, nickname: nickname.trimmed, password: password)
            }
            let response: AuthResponse = try await api.send(endpoint)
            tokenStore.save(response.token)
            tokenStore.nickname = response.user.nickname
            password = ""
            onLoggedIn?()
        } catch let error as APIClient.ServerError {
            // Turn server codes into text in the phone's language.
            errorMessage = switch error.status {
            case 401: String(localized: "Wrong login or password")
            case 409: String(localized: "This email or nickname is already taken")
            default: error.reason  // validation messages from Vapor, in English
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private extension String {
    var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }
}
