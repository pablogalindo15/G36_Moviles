import Foundation
import Security

enum KeychainError: Error, LocalizedError {
    case saveFailed(OSStatus)
    case deleteFailed(OSStatus)
    case dataEncodingFailed

    var errorDescription: String? {
        switch self {
        case .saveFailed(let status):   return "Keychain save failed (\(status))"
        case .deleteFailed(let status): return "Keychain delete failed (\(status))"
        case .dataEncodingFailed:       return "Keychain data encoding failed"
        }
    }
}

/// Simple wrapper over iOS Keychain Services for storing sensitive strings.
/// Uses kSecClassGenericPassword with kSecAttrAccessibleAfterFirstUnlock:
/// accessible after the first device unlock post-boot, inaccessible while locked.
/// All app credentials are namespaced under service "ai.fluxo.app".
final class KeychainAdapter {

    private let service = "ai.fluxo.app"

    // MARK: - Public API

    func save(_ value: String, forKey key: String) throws {
        guard let data = value.data(using: .utf8) else {
            throw KeychainError.dataEncodingFailed
        }

        // Upsert: delete any existing item first (Apple's recommended pattern).
        deleteIgnoringError(forKey: key)

        let query: [String: Any] = [
            kSecClass as String:            kSecClassGenericPassword,
            kSecAttrService as String:      service,
            kSecAttrAccount as String:      key,
            kSecValueData as String:        data,
            kSecAttrAccessible as String:   kSecAttrAccessibleAfterFirstUnlock
        ]

        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainError.saveFailed(status)
        }
    }

    func load(forKey key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String:        kSecClassGenericPassword,
            kSecAttrService as String:  service,
            kSecAttrAccount as String:  key,
            kSecReturnData as String:   true,
            kSecMatchLimit as String:   kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess,
              let data = result as? Data,
              let value = String(data: data, encoding: .utf8)
        else { return nil }

        return value
    }

    func delete(forKey key: String) throws {
        let status = deleteIgnoringError(forKey: key)
        // errSecItemNotFound is acceptable — item already absent.
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.deleteFailed(status)
        }
    }

    // MARK: - Private

    @discardableResult
    private func deleteIgnoringError(forKey key: String) -> OSStatus {
        let query: [String: Any] = [
            kSecClass as String:        kSecClassGenericPassword,
            kSecAttrService as String:  service,
            kSecAttrAccount as String:  key
        ]
        return SecItemDelete(query as CFDictionary)
    }
}
