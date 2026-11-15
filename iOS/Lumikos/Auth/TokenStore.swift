import Foundation
import Security

/// Keeps the login token in the Keychain (encrypted by iOS, survives app reinstall on the same phone).
/// Never put tokens or passwords into UserDefaults: that is a plain file.
@MainActor
final class TokenStore {
    private let service = "com.disavle.lumikos"
    private let account = "token"

    /// Read once from the Keychain, then kept in memory.
    private(set) lazy var token: String? = read()

    /// The nickname is not a secret, so UserDefaults is fine for it.
    var nickname: String? {
        get { UserDefaults.standard.string(forKey: "nickname") }
        set { UserDefaults.standard.set(newValue, forKey: "nickname") }
    }

    func save(_ token: String) {
        delete()
        let item: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: Data(token.utf8),
            // Readable only when the phone has been unlocked at least once after a restart.
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock,
        ]
        SecItemAdd(item as CFDictionary, nil)
        self.token = token
    }

    func clear() {
        delete()
        token = nil
        nickname = nil
    }

    private func read() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
        ]
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data
        else { return nil }
        return String(decoding: data, as: UTF8.self)
    }

    private func delete() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        SecItemDelete(query as CFDictionary)
    }
}
