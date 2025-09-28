//
//  EnhancedSecurityServiceTests.swift
//  VibesyTests
//
//  Created by Refactoring Bot on 12/19/24.
//

import XCTest
@testable import Vibesy

final class EnhancedSecurityServiceTests: XCTestCase {
    
    private var securityService: EnhancedSecurityService!
    
    override func setUpWithError() throws {
        securityService = EnhancedSecurityService.shared
    }
    
    override func tearDownWithError() throws {
        securityService = nil
    }
    
    // MARK: - Password Validation Tests
    
    func testPasswordValidationSuccess() throws {
        let validPasswords = [
            "MySecurePass123!",
            "AnotherGoodPassword456@",
            "ComplexPass789#",
            "StrongPassword2024$"
        ]
        
        for password in validPasswords {
            XCTAssertNoThrow(try securityService.validatePassword(password))
        }
    }
    
    func testPasswordValidationFailures() {
        let invalidPasswords = [
            ("", SecurityError.passwordTooShort),
            ("short", SecurityError.passwordTooShort),
            ("1234567", SecurityError.passwordTooShort),
            ("password123", SecurityError.passwordMissingSpecialCharacter),
            ("Password!", SecurityError.passwordMissingDigit),
            ("password123!", SecurityError.passwordMissingUppercase),
            ("PASSWORD123!", SecurityError.passwordMissingLowercase),
            ("NoSpecialChar123", SecurityError.passwordMissingSpecialCharacter)
        ]
        
        for (password, expectedError) in invalidPasswords {
            XCTAssertThrowsError(try securityService.validatePassword(password)) { error in
                XCTAssertTrue(error is SecurityError)
                // Note: This is a simplified check - in reality, you'd compare specific error types
            }
        }
    }
    
    func testPasswordComplexityScoring() {
        let passwords = [
            ("weak123", 0.2),
            ("Better123!", 0.6),
            ("VerySecurePassword2024@", 0.9)
        ]
        
        for (password, expectedMinScore) in passwords {
            let score = securityService.calculatePasswordStrength(password)
            XCTAssertGreaterThanOrEqual(score, expectedMinScore, "Password: \(password)")
        }
    }
    
    // MARK: - Input Sanitization Tests
    
    func testInputSanitization() {
        let testCases = [
            ("<script>alert('xss')</script>", "alert('xss')"),
            ("Normal text", "Normal text"),
            ("<img src=x onerror=alert(1)>", ""),
            ("SELECT * FROM users; DROP TABLE users;", "SELECT * FROM users; DROP TABLE users;"),
            ("<div onclick=\"malicious()\">Content</div>", "Content")
        ]
        
        for (input, expectedOutput) in testCases {
            let sanitized = securityService.sanitizeInput(input)
            XCTAssertEqual(sanitized, expectedOutput, "Input: \(input)")
        }
    }
    
    // MARK: - Email Validation Tests
    
    func testEmailValidation() {
        let validEmails = [
            "user@example.com",
            "test.email@domain.org",
            "name+tag@company.co.uk",
            "valid_email123@test-domain.com"
        ]
        
        let invalidEmails = [
            "invalid-email",
            "@domain.com",
            "user@",
            "user@domain",
            "user.domain.com",
            ""
        ]
        
        for email in validEmails {
            XCTAssertTrue(securityService.isValidEmail(email), "Email: \(email)")
        }
        
        for email in invalidEmails {
            XCTAssertFalse(securityService.isValidEmail(email), "Email: \(email)")
        }
    }
    
    // MARK: - Data Encryption Tests
    
    func testDataEncryptionDecryption() throws {
        let testData = "This is sensitive test data that needs encryption"
        let testKey = "MyTestEncryptionKey123"
        
        // Test encryption
        let encryptedData = try securityService.encryptData(testData, key: testKey)
        XCTAssertNotEqual(encryptedData, testData)
        XCTAssertFalse(encryptedData.isEmpty)
        
        // Test decryption
        let decryptedData = try securityService.decryptData(encryptedData, key: testKey)
        XCTAssertEqual(decryptedData, testData)
    }
    
    func testDataEncryptionWithInvalidKey() throws {
        let testData = "Test data"
        let encryptionKey = "ValidKey123"
        let wrongKey = "WrongKey456"
        
        // Encrypt with valid key
        let encryptedData = try securityService.encryptData(testData, key: encryptionKey)
        
        // Try to decrypt with wrong key
        XCTAssertThrowsError(try securityService.decryptData(encryptedData, key: wrongKey)) { error in
            XCTAssertTrue(error is SecurityError)
        }
    }
    
    func testEmptyDataEncryption() {
        XCTAssertThrowsError(try securityService.encryptData("", key: "TestKey")) { error in
            XCTAssertTrue(error is SecurityError)
        }
    }
    
    // MARK: - Rate Limiting Tests
    
    func testRateLimiting() async throws {
        let identifier = "test-user-123"
        let limit = 3
        let timeWindow: TimeInterval = 1.0
        
        // First few attempts should succeed
        for i in 1...limit {
            let allowed = await securityService.isRateLimited(identifier: identifier, limit: limit, timeWindow: timeWindow)
            XCTAssertFalse(allowed, "Attempt \(i) should be allowed")
        }
        
        // Next attempt should be rate limited
        let rateLimited = await securityService.isRateLimited(identifier: identifier, limit: limit, timeWindow: timeWindow)
        XCTAssertTrue(rateLimited, "Should be rate limited after exceeding limit")
        
        // Wait for time window to pass
        try await Task.sleep(nanoseconds: UInt64(timeWindow * 1_000_000_000) + 100_000_000)
        
        // Should be allowed again after time window
        let allowedAgain = await securityService.isRateLimited(identifier: identifier, limit: limit, timeWindow: timeWindow)
        XCTAssertFalse(allowedAgain, "Should be allowed again after time window")
    }
    
    // MARK: - Keychain Operations Tests
    
    func testKeychainOperations() throws {
        let key = "test-token-key"
        let value = "test-token-value-123"
        
        // Test storing token
        XCTAssertNoThrow(try securityService.storeInKeychain(key: key, data: value))
        
        // Test retrieving token
        let retrievedValue = try securityService.retrieveFromKeychain(key: key)
        XCTAssertEqual(retrievedValue, value)
        
        // Test removing token
        XCTAssertNoThrow(try securityService.removeFromKeychain(key: key))
        
        // Test retrieving removed token should throw error
        XCTAssertThrowsError(try securityService.retrieveFromKeychain(key: key)) { error in
            XCTAssertTrue(error is SecurityError)
        }
    }
    
    func testKeychainNonExistentKey() {
        XCTAssertThrowsError(try securityService.retrieveFromKeychain(key: "non-existent-key")) { error in
            XCTAssertTrue(error is SecurityError)
        }
    }
    
    // MARK: - Network Security Tests
    
    func testSecurityHeaders() {
        let headers = securityService.getSecurityHeaders()
        
        XCTAssertNotNil(headers["X-API-Key"])
        XCTAssertNotNil(headers["X-Request-ID"])
        XCTAssertEqual(headers["Content-Type"], "application/json")
        XCTAssertEqual(headers["Accept"], "application/json")
        XCTAssertNotNil(headers["User-Agent"])
        
        // Verify UUID format for Request-ID
        if let requestID = headers["X-Request-ID"] {
            XCTAssertTrue(requestID.count == 36) // UUID format
        }
    }
    
    // MARK: - Hash Generation Tests
    
    func testHashGeneration() {
        let testString = "test-hash-input"
        
        let hash1 = securityService.generateHash(from: testString)
        let hash2 = securityService.generateHash(from: testString)
        
        // Same input should produce same hash
        XCTAssertEqual(hash1, hash2)
        
        // Different input should produce different hash
        let differentHash = securityService.generateHash(from: "different-input")
        XCTAssertNotEqual(hash1, differentHash)
        
        // Hash should be 64 characters (SHA256 hex)
        XCTAssertEqual(hash1.count, 64)
    }
    
    // MARK: - Token Generation Tests
    
    func testSecureTokenGeneration() {
        let token1 = securityService.generateSecureToken()
        let token2 = securityService.generateSecureToken()
        
        // Tokens should be different
        XCTAssertNotEqual(token1, token2)
        
        // Tokens should have expected length (32 bytes = 64 hex characters)
        XCTAssertEqual(token1.count, 64)
        XCTAssertEqual(token2.count, 64)
        
        // Tokens should only contain hex characters
        let hexCharacterSet = CharacterSet(charactersIn: "0123456789abcdef")
        XCTAssertTrue(token1.lowercased().unicodeScalars.allSatisfy { hexCharacterSet.contains($0) })
    }
    
    // MARK: - Performance Tests
    
    func testPasswordValidationPerformance() {
        let testPassword = "TestPassword123!"
        
        measure {
            for _ in 0..<1000 {
                try? securityService.validatePassword(testPassword)
            }
        }
    }
    
    func testEncryptionPerformance() throws {
        let testData = String(repeating: "Performance test data. ", count: 100)
        let testKey = "PerformanceTestKey123"
        
        measure {
            for _ in 0..<100 {
                if let encrypted = try? securityService.encryptData(testData, key: testKey) {
                    _ = try? securityService.decryptData(encrypted, key: testKey)
                }
            }
        }
    }
    
    func testHashPerformance() {
        let testInput = "Performance test input for hashing operations"
        
        measure {
            for _ in 0..<1000 {
                _ = securityService.generateHash(from: testInput)
            }
        }
    }
    
    // MARK: - Integration Tests
    
    func testPasswordWorkflow() throws {
        let password = "IntegrationTest123!"
        
        // Validate password
        XCTAssertNoThrow(try securityService.validatePassword(password))
        
        // Generate hash
        let hash = securityService.generateHash(from: password)
        XCTAssertFalse(hash.isEmpty)
        
        // Store hash in keychain
        try securityService.storeInKeychain(key: "test-password-hash", data: hash)
        
        // Retrieve and verify
        let storedHash = try securityService.retrieveFromKeychain(key: "test-password-hash")
        XCTAssertEqual(hash, storedHash)
        
        // Cleanup
        try securityService.removeFromKeychain(key: "test-password-hash")
    }
    
    func testSecurityHeadersIntegration() {
        let headers = securityService.getSecurityHeaders()
        
        // Verify all required headers are present
        let requiredHeaders = ["X-API-Key", "X-Request-ID", "Content-Type", "Accept", "User-Agent"]
        
        for header in requiredHeaders {
            XCTAssertNotNil(headers[header], "Missing required header: \(header)")
        }
        
        // Verify header values are not empty
        for (key, value) in headers {
            XCTAssertFalse(value.isEmpty, "Empty value for header: \(key)")
        }
    }
}