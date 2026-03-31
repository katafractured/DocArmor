import Foundation
import CryptoKit
import Security

/// Manages the AES-256 master key stored in the Keychain.
///
/// Key attributes:
/// - `kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly`: never backs up to iCloud,
///   never transfers to other devices, deleted if device passcode is removed.
enum VaultKey {
    nonisolated private static let service = "com.katafract.docarmor"
    nonisolated private static let account = "vault-master-key"

    // MARK: - Public API

    /// Load the existing vault key from the Keychain.
    /// - Throws: `VaultKeyError.notFound` if no key exists yet (first launch).
    ///           Other `VaultKeyError` cases for Keychain failures.
    nonisolated static func load() throws -> SymmetricKey {
        let query: [CFString: Any] = [
            kSecClass:            kSecClassGenericPassword,
            kSecAttrService:      service,
            kSecAttrAccount:      account,
            kSecReturnData:       true,
            kSecMatchLimit:       kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        switch status {
        case errSecSuccess:
            guard let data = result as? Data else {
                throw VaultKeyError.invalidData
            }
            return SymmetricKey(data: data)
        case errSecItemNotFound:
            throw VaultKeyError.notFound
        default:
            throw VaultKeyError.keychainError(status)
        }
    }

    nonisolated static func exportKeyData() throws -> Data {
        let key = try load()
        return key.withUnsafeBytes { Data($0) }
    }

    /// Generate a new AES-256 key and persist it in the Keychain.
    /// Call only on first launch (when `load()` throws `.notFound`).
    @discardableResult
    nonisolated static func generate() throws -> SymmetricKey {
        let key = SymmetricKey(size: .bits256)
        let keyData = key.withUnsafeBytes { Data($0) }

        #if targetEnvironment(simulator)
        let accessibility = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        #else
        let accessibility = kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly
        #endif

        let attributes: [CFString: Any] = [
            kSecClass:                   kSecClassGenericPassword,
            kSecAttrService:             service,
            kSecAttrAccount:             account,
            kSecValueData:               keyData,
            kSecAttrAccessible:          accessibility
        ]

        let status = SecItemAdd(attributes as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw VaultKeyError.keychainError(status)
        }
        return key
    }

    /// Delete the vault key from the Keychain, permanently destroying all encrypted data.
    /// Used by "Reset Vault" — encrypted document data becomes unrecoverable without the key.
    nonisolated static func delete() throws {
        let query: [CFString: Any] = [
            kSecClass:       kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account
        ]

        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw VaultKeyError.keychainError(status)
        }
    }

    nonisolated static func replace(with keyData: Data) throws {
        try delete()
        try store(keyData: keyData)
    }

    /// Returns `true` if a vault key exists in the Keychain (app has been set up before).
    ///
    /// Uses an attribute-only query (`kSecReturnData: false`) so key bytes are never
    /// materialized in memory just to answer a boolean question.
    nonisolated static var exists: Bool {
        let query: [CFString: Any] = [
            kSecClass:           kSecClassGenericPassword,
            kSecAttrService:     service,
            kSecAttrAccount:     account,
            kSecReturnData:      false,
            kSecReturnAttributes: true,
            kSecMatchLimit:      kSecMatchLimitOne
        ]
        var result: AnyObject?
        return SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess
    }

    nonisolated private static func store(keyData: Data) throws {
        #if targetEnvironment(simulator)
        let accessibility = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        #else
        let accessibility = kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly
        #endif

        let attributes: [CFString: Any] = [
            kSecClass:                   kSecClassGenericPassword,
            kSecAttrService:             service,
            kSecAttrAccount:             account,
            kSecValueData:               keyData,
            kSecAttrAccessible:          accessibility
        ]

        let status = SecItemAdd(attributes as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw VaultKeyError.keychainError(status)
        }
    }
}

// MARK: - Errors

enum VaultKeyError: LocalizedError {
    case notFound
    case invalidData
    case keychainError(OSStatus)

    var errorDescription: String? {
        switch self {
        case .notFound:
            return "No vault key found. This is expected on first launch."
        case .invalidData:
            return "Vault key data in Keychain is invalid."
        case .keychainError(let status):
            return "Keychain error: \(status)"
        }
    }
}
