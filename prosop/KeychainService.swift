//
//  KeychainService.swift
//  Prosop
//
//  Created by Arvat Vladimir on 15.03.2026.
//

import Foundation
import Security

/// Secure storage service using iOS Keychain for sensitive data like API keys
enum KeychainService {
    
    /// Saves a string value to the keychain
    /// - Parameters:
    ///   - key: The key to store the value under
    ///   - value: The string value to store
    /// - Throws: KeychainError if the operation fails
    static func save(key: String, value: String) throws {
        guard let data = value.data(using: .utf8) else {
            throw KeychainError.invalidData
        }
        
        // First, delete any existing item
        let deleteQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key
        ]
        SecItemDelete(deleteQuery as CFDictionary)
        
        // Now add the new item
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainError.saveFailed(status: status)
        }
    }
    
    /// Loads a string value from the keychain
    /// - Parameter key: The key to retrieve the value for
    /// - Returns: The stored string value, or nil if not found
    static func load(key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String: kCFBooleanTrue as Any,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var dataTypeRef: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &dataTypeRef)
        
        guard status == errSecSuccess,
              let data = dataTypeRef as? Data,
              let value = String(data: data, encoding: .utf8) else {
            return nil
        }
        
        return value
    }
    
    /// Deletes a value from the keychain
    /// - Parameter key: The key to delete
    /// - Throws: KeychainError if the operation fails
    static func delete(key: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.deleteFailed(status: status)
        }
    }
    
    /// Checks if a key exists in the keychain
    /// - Parameter key: The key to check
    /// - Returns: True if the key exists, false otherwise
    static func exists(key: String) -> Bool {
        return load(key: key) != nil
    }
}

// MARK: - Keychain Errors
enum KeychainError: LocalizedError {
    case invalidData
    case saveFailed(status: OSStatus)
    case deleteFailed(status: OSStatus)
    
    var errorDescription: String? {
        switch self {
        case .invalidData:
            return "Invalid data format for keychain storage"
        case .saveFailed(let status):
            return "Failed to save to keychain (status: \(status))"
        case .deleteFailed(let status):
            return "Failed to delete from keychain (status: \(status))"
        }
    }
}

// MARK: - Convenience Extensions for API Key
extension KeychainService {
    private static let apiKeyKey = "com.prosop.openai.apikey"
    
    /// Saves the OpenAI API key securely
    static func saveAPIKey(_ key: String) throws {
        try save(key: apiKeyKey, value: key)
    }
    
    /// Loads the OpenAI API key
    static func loadAPIKey() -> String? {
        return load(key: apiKeyKey)
    }
    
    /// Deletes the OpenAI API key
    static func deleteAPIKey() throws {
        try delete(key: apiKeyKey)
    }
    
    /// Checks if an API key exists
    static var hasAPIKey: Bool {
        return exists(key: apiKeyKey)
    }
}
