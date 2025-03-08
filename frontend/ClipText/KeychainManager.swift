import Foundation

final class KeychainManager {
    static let shared = KeychainManager()

    private init() {}

    func saveAPIKey(_ apiKey: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: "GeminiAPIKey",
            kSecValueData as String: apiKey.data(using: .utf8)!
        ]

        SecItemDelete(query as CFDictionary)
        let status = SecItemAdd(query as CFDictionary, nil)
        if status != errSecSuccess {
            throw KeychainError.saveFailed
        }
    }

    func retrieveAPIKey() throws -> String {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: "GeminiAPIKey",
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        if status != errSecSuccess {
            throw KeychainError.retrieveFailed
        }

        guard let data = item as? Data,
              let apiKey = String(data: data, encoding: .utf8) else {
            throw KeychainError.invalidData
        }

        return apiKey
    }
}

enum KeychainError: Error {
    case saveFailed
    case retrieveFailed
    case invalidData
}