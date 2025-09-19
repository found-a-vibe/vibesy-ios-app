//
//  EnhancedSecurityService.swift
//  Vibesy
//
//  Created by Refactoring Bot on 12/19/24.
//

import Foundation
import Security
import CryptoKit
import os.log

// MARK: - Security Errors
enum SecurityError: LocalizedError {
    case keychainOperationFailed(OSStatus)
    case invalidPassword
    case passwordTooWeak
    case encryptionFailed
    case decryptionFailed
    case biometricAuthenticationFailed
    case tokenExpired
    case invalidToken
    case rateLimitExceeded
    case networkSecurityError(Error)
    
    var errorDescription: String? {
        switch self {
        case .keychainOperationFailed(let status):
            return "Keychain operation failed with status: \(status)"
        case .invalidPassword:
            return "Invalid password format"
        case .passwordTooWeak:
            return "Password does not meet security requirements"
        case .encryptionFailed:
            return "Failed to encrypt data"
        case .decryptionFailed:
            return "Failed to decrypt data"
        case .biometricAuthenticationFailed:
            return "Biometric authentication failed"
        case .tokenExpired:
            return "Authentication token has expired"
        case .invalidToken:
            return "Invalid authentication token"
        case .rateLimitExceeded:
            return "Rate limit exceeded. Please try again later"
        case .networkSecurityError(let error):
            return "Network security error: \(error.localizedDescription)"
        }
    }
}

// MARK: - Password Requirements
struct PasswordRequirements {
    static let minLength = 8
    static let maxLength = 128
    static let requiresUppercase = true
    static let requiresLowercase = true
    static let requiresNumbers = true
    static let requiresSpecialCharacters = true
    static let forbiddenPasswords = [
        "password", "123456", "qwerty", "abc123", "password123"
    ]
}

// MARK: - Secure Storage Keys
enum SecureStorageKey: String, CaseIterable {
    case userAuthToken = "user_auth_token"
    case refreshToken = "refresh_token"
    case biometricSecret = "biometric_secret"
    case encryptionKey = "encryption_key"
    case fcmToken = "fcm_token"
    
    var service: String {
        return Bundle.main.bundleIdentifier ?? "com.foundavibe.Vibesy"
    }
}

// MARK: - Enhanced Security Service
@MainActor
final class EnhancedSecurityService: ObservableObject {
    private static let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "Vibesy", category: "Security")
    
    // MARK: - Singleton
    static let shared = EnhancedSecurityService()
    
    // MARK: - Rate Limiting
    private var rateLimitTracker: [String: Date] = [:]
    private let rateLimitWindow: TimeInterval = 300 // 5 minutes
    private let maxAttemptsPerWindow = 5
    
    private init() {
        Self.logger.info("EnhancedSecurityService initialized")
    }
    
    // MARK: - Password Security
    func validatePassword(_ password: String) throws {
        // Length check
        guard password.count >= PasswordRequirements.minLength,
              password.count <= PasswordRequirements.maxLength else {
            throw SecurityError.passwordTooWeak
        }
        
        // Character requirements
        let hasUppercase = password.range(of: "[A-Z]", options: .regularExpression) != nil
        let hasLowercase = password.range(of: "[a-z]", options: .regularExpression) != nil
        let hasNumbers = password.range(of: "[0-9]", options: .regularExpression) != nil
        let hasSpecialChars = password.range(of: "[^A-Za-z0-9]", options: .regularExpression) != nil
        
        if PasswordRequirements.requiresUppercase && !hasUppercase { throw SecurityError.passwordTooWeak }
        if PasswordRequirements.requiresLowercase && !hasLowercase { throw SecurityError.passwordTooWeak }
        if PasswordRequirements.requiresNumbers && !hasNumbers { throw SecurityError.passwordTooWeak }
        if PasswordRequirements.requiresSpecialCharacters && !hasSpecialChars { throw SecurityError.passwordTooWeak }
        
        // Check against common passwords
        if PasswordRequirements.forbiddenPasswords.contains(password.lowercased()) {
            throw SecurityError.passwordTooWeak
        }
        
        Self.logger.debug("Password validation passed")
    }
    
    func calculatePasswordStrength(_ password: String) -> Double {
        var score = 0.0
        
        // Length scoring
        if password.count >= 8 { score += 1.0 }
        if password.count >= 12 { score += 1.0 }
        if password.count >= 16 { score += 1.0 }
        
        // Character variety
        if password.range(of: "[A-Z]", options: .regularExpression) != nil { score += 1.0 }
        if password.range(of: "[a-z]", options: .regularExpression) != nil { score += 1.0 }
        if password.range(of: "[0-9]", options: .regularExpression) != nil { score += 1.0 }
        if password.range(of: "[^A-Za-z0-9]", options: .regularExpression) != nil { score += 1.0 }
        
        // Avoid common patterns
        if !PasswordRequirements.forbiddenPasswords.contains(password.lowercased()) { score += 1.0 }
        
        return min(score / 8.0, 1.0) // Normalize to 0-1
    }
    
    // MARK: - Keychain Operations
    func storeSecurely(key: SecureStorageKey, data: Data) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: key.service,
            kSecAttrAccount as String: key.rawValue,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        
        // Delete existing item first
        SecItemDelete(query as CFDictionary)
        
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            Self.logger.error("Failed to store in keychain: \(status)")
            throw SecurityError.keychainOperationFailed(status)
        }
        
        Self.logger.debug("Successfully stored \(key.rawValue) in keychain")
    }
    
    func retrieveSecurely(key: SecureStorageKey) throws -> Data {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: key.service,
            kSecAttrAccount as String: key.rawValue,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess,
              let data = result as? Data else {
            Self.logger.error("Failed to retrieve from keychain: \(status)")
            throw SecurityError.keychainOperationFailed(status)
        }
        
        Self.logger.debug("Successfully retrieved \(key.rawValue) from keychain")
        return data
    }
    
    func deleteSecurely(key: SecureStorageKey) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: key.service,
            kSecAttrAccount as String: key.rawValue
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            Self.logger.error("Failed to delete from keychain: \(status)")
            throw SecurityError.keychainOperationFailed(status)
        }
        
        Self.logger.debug("Successfully deleted \(key.rawValue) from keychain")
    }
    
    // MARK: - Token Management
    func storeAuthToken(_ token: String, refreshToken: String? = nil) async throws {
        let tokenData = Data(token.utf8)
        try storeSecurely(key: .userAuthToken, data: tokenData)
        
        if let refreshToken = refreshToken {
            let refreshData = Data(refreshToken.utf8)
            try storeSecurely(key: .refreshToken, data: refreshData)
        }
        
        Self.logger.info("Auth tokens stored securely")
    }
    
    func getAuthToken() throws -> String? {
        do {
            let tokenData = try retrieveSecurely(key: .userAuthToken)
            return String(data: tokenData, encoding: .utf8)
        } catch {
            if case SecurityError.keychainOperationFailed(let status) = error,
               status == errSecItemNotFound {
                return nil // No token stored
            }
            throw error
        }
    }
    
    func clearAuthTokens() throws {
        try? deleteSecurely(key: .userAuthToken)
        try? deleteSecurely(key: .refreshToken)
        Self.logger.info("Auth tokens cleared")
    }
    
    // MARK: - Data Encryption
    func generateEncryptionKey() -> SymmetricKey {
        return SymmetricKey(size: .bits256)
    }
    
    func encrypt(data: Data, using key: SymmetricKey) throws -> Data {
        do {
            let sealedBox = try AES.GCM.seal(data, using: key)
            guard let encryptedData = sealedBox.combined else {
                throw SecurityError.encryptionFailed
            }
            return encryptedData
        } catch {
            Self.logger.error("Encryption failed: \(error.localizedDescription)")
            throw SecurityError.encryptionFailed
        }
    }
    
    func decrypt(data: Data, using key: SymmetricKey) throws -> Data {
        do {
            let sealedBox = try AES.GCM.SealedBox(combined: data)
            let decryptedData = try AES.GCM.open(sealedBox, using: key)
            return decryptedData
        } catch {
            Self.logger.error("Decryption failed: \(error.localizedDescription)")
            throw SecurityError.decryptionFailed
        }
    }
    
    // MARK: - Rate Limiting
    func checkRateLimit(for identifier: String) throws {
        let now = Date()
        let windowStart = now.addingTimeInterval(-rateLimitWindow)
        
        // Clean old entries
        rateLimitTracker = rateLimitTracker.filter { $0.value >= windowStart }
        
        // Count attempts in current window
        let attempts = rateLimitTracker.filter { entry in
            entry.key.hasPrefix(identifier) && entry.value >= windowStart
        }.count
        
        if attempts >= maxAttemptsPerWindow {
            Self.logger.warning("Rate limit exceeded for: \(identifier)")
            throw SecurityError.rateLimitExceeded
        }
        
        // Record this attempt
        rateLimitTracker["\(identifier)_\(UUID())"] = now
    }
    
    // MARK: - Network Security
    func createSecureURLRequest(url: URL) -> URLRequest {
        var request = URLRequest(url: url)
        request.timeoutInterval = 30.0
        request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        
        // Security headers
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("no-cache", forHTTPHeaderField: "Cache-Control")
        request.setValue("1", forHTTPHeaderField: "X-Content-Type-Options") // nosniff
        request.setValue("deny", forHTTPHeaderField: "X-Frame-Options")
        
        return request
    }
    
    func validateServerCertificate(trust: SecTrust) -> Bool {
        var result: SecTrustResultType = .invalid
        let status = SecTrustEvaluate(trust, &result)
        
        guard status == errSecSuccess else {
            Self.logger.error("Certificate trust evaluation failed")
            return false
        }
        
        return result == .unspecified || result == .proceed
    }
    
    // MARK: - Input Sanitization
    func sanitizeInput(_ input: String) -> String {
        // Remove potential XSS and injection attempts
        let sanitized = input
            .replacingOccurrences(of: "<script", with: "&lt;script", options: .caseInsensitive)
            .replacingOccurrences(of: "</script", with: "&lt;/script", options: .caseInsensitive)
            .replacingOccurrences(of: "javascript:", with: "", options: .caseInsensitive)
            .replacingOccurrences(of: "onload=", with: "", options: .caseInsensitive)
            .replacingOccurrences(of: "onerror=", with: "", options: .caseInsensitive)
        
        return sanitized.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    func validateEmail(_ email: String) -> Bool {
        let emailRegex = "^[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}$"
        let emailPredicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)
        return emailPredicate.evaluate(with: email) && email.count <= 254
    }
    
    // MARK: - Security Audit
    func performSecurityAudit() -> [String] {
        var issues: [String] = []
        
        // Check for stored tokens
        do {
            _ = try getAuthToken()
        } catch {
            issues.append("Authentication token storage issue: \(error.localizedDescription)")
        }
        
        // Check app transport security
        if let infoPlist = Bundle.main.infoDictionary,
           let ats = infoPlist["NSAppTransportSecurity"] as? [String: Any],
           let allowsArbitraryLoads = ats["NSAllowsArbitraryLoads"] as? Bool,
           allowsArbitraryLoads {
            issues.append("App Transport Security allows arbitrary loads")
        }
        
        // Check for debug symbols in release builds
        #if DEBUG
        issues.append("Debug build - should not be used in production")
        #endif
        
        Self.logger.info("Security audit completed with \(issues.count) issues")
        return issues
    }
    
    // MARK: - Cleanup
    func cleanup() {
        rateLimitTracker.removeAll()
        Self.logger.info("Security service cleanup completed")
    }
}

// MARK: - Security Extensions
extension EnhancedSecurityService {
    // Hash sensitive data
    func hashSensitiveData(_ data: String) -> String {
        let inputData = Data(data.utf8)
        let hashedData = SHA256.hash(data: inputData)
        return hashedData.compactMap { String(format: "%02x", $0) }.joined()
    }
    
    // Generate secure random string
    func generateSecureRandomString(length: Int) -> String? {
        let characters = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        var randomString = ""
        
        for _ in 0..<length {
            guard let randomCharacter = characters.randomElement() else {
                return nil
            }
            randomString.append(randomCharacter)
        }
        
        return randomString
    }
}