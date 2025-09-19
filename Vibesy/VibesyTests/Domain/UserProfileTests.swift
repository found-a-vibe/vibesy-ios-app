//
//  UserProfileTests.swift
//  VibesyTests
//
//  Created by Refactoring Bot on 12/19/24.
//

import XCTest
@testable import Vibesy

final class UserProfileTests: XCTestCase {
    
    override func setUpWithError() throws {
        // Setup code here
    }
    
    override func tearDownWithError() throws {
        // Cleanup code here
    }
    
    // MARK: - UserProfile Creation Tests
    
    func testUserProfileCreationSuccess() throws {
        let userProfile = try UserProfile(
            uid: "test-user-123",
            email: "test@example.com",
            displayName: "Test User",
            phoneNumber: "+1234567890",
            birthDate: "1990-01-01"
        )
        
        XCTAssertEqual(userProfile.uid, "test-user-123")
        XCTAssertEqual(userProfile.email, "test@example.com")
        XCTAssertEqual(userProfile.displayName, "Test User")
        XCTAssertEqual(userProfile.phoneNumber, "+1234567890")
        XCTAssertEqual(userProfile.birthDate, "1990-01-01")
        XCTAssertTrue(userProfile.isComplete)
    }
    
    func testUserProfileCreationWithInvalidUID() {
        XCTAssertThrowsError(try UserProfile(
            uid: "",
            email: "test@example.com",
            displayName: "Test User"
        )) { error in
            XCTAssertTrue(error is UserProfileError)
            if case UserProfileError.invalidUID(let uid) = error {
                XCTAssertEqual(uid, "")
            } else {
                XCTFail("Expected UserProfileError.invalidUID")
            }
        }
    }
    
    func testUserProfileCreationWithInvalidEmail() {
        XCTAssertThrowsError(try UserProfile(
            uid: "test-user-123",
            email: "invalid-email",
            displayName: "Test User"
        )) { error in
            XCTAssertTrue(error is UserProfileError)
            if case UserProfileError.invalidEmail(let email) = error {
                XCTAssertEqual(email, "invalid-email")
            } else {
                XCTFail("Expected UserProfileError.invalidEmail")
            }
        }
    }
    
    // MARK: - Validation Tests
    
    func testEmailValidation() throws {
        var userProfile = try UserProfile(
            uid: "test-user-123",
            email: "test@example.com",
            displayName: "Test User"
        )
        
        // Test valid emails
        let validEmails = [
            "user@domain.com",
            "test.email@example.org",
            "name+tag@domain.co.uk"
        ]
        
        for email in validEmails {
            userProfile.email = email
            XCTAssertNoThrow(try userProfile.validate())
        }
        
        // Test invalid emails
        let invalidEmails = [
            "invalid-email",
            "@domain.com",
            "user@",
            "user@domain"
        ]
        
        for email in invalidEmails {
            userProfile.email = email
            XCTAssertThrowsError(try userProfile.validate()) { error in
                XCTAssertTrue(error is UserProfileError)
            }
        }
    }
    
    func testDisplayNameValidation() throws {
        var userProfile = try UserProfile(
            uid: "test-user-123",
            email: "test@example.com",
            displayName: "Test User"
        )
        
        // Test valid display names
        userProfile.displayName = "Valid Name"
        XCTAssertNoThrow(try userProfile.validate())
        
        // Test empty display name
        userProfile.displayName = ""
        XCTAssertThrowsError(try userProfile.validate()) { error in
            if case UserProfileError.invalidDisplayName(_) = error {
                // Expected error
            } else {
                XCTFail("Expected UserProfileError.invalidDisplayName")
            }
        }
        
        // Test display name that's too long
        userProfile.displayName = String(repeating: "a", count: 51)
        XCTAssertThrowsError(try userProfile.validate()) { error in
            if case UserProfileError.invalidDisplayName(_) = error {
                // Expected error
            } else {
                XCTFail("Expected UserProfileError.invalidDisplayName")
            }
        }
    }
    
    func testPhoneNumberValidation() throws {
        var userProfile = try UserProfile(
            uid: "test-user-123",
            email: "test@example.com",
            displayName: "Test User"
        )
        
        // Test valid phone numbers
        let validPhones = [
            "+1234567890",
            "+44123456789",
            "+33123456789"
        ]
        
        for phone in validPhones {
            userProfile.phoneNumber = phone
            XCTAssertNoThrow(try userProfile.validate())
        }
        
        // Test invalid phone numbers
        let invalidPhones = [
            "123456789", // Missing + prefix
            "+123",      // Too short
            "abc123",    // Contains letters
            ""           // Empty
        ]
        
        for phone in invalidPhones {
            userProfile.phoneNumber = phone
            XCTAssertThrowsError(try userProfile.validate()) { error in
                XCTAssertTrue(error is UserProfileError)
            }
        }
    }
    
    // MARK: - Bio Management Tests
    
    func testBioValidation() throws {
        var userProfile = try UserProfile(
            uid: "test-user-123",
            email: "test@example.com",
            displayName: "Test User"
        )
        
        // Test valid bio
        userProfile.bio = "This is a valid bio under the character limit."
        XCTAssertNoThrow(try userProfile.validate())
        
        // Test bio that's too long
        userProfile.bio = String(repeating: "a", count: 501)
        XCTAssertThrowsError(try userProfile.validate()) { error in
            if case UserProfileError.invalidBio(_) = error {
                // Expected error
            } else {
                XCTFail("Expected UserProfileError.invalidBio")
            }
        }
        
        // Test empty bio (should be valid)
        userProfile.bio = ""
        XCTAssertNoThrow(try userProfile.validate())
    }
    
    // MARK: - Social Links Tests
    
    func testSocialLinksManagement() throws {
        var userProfile = try UserProfile(
            uid: "test-user-123",
            email: "test@example.com",
            displayName: "Test User"
        )
        
        // Test adding valid social links
        try userProfile.addSocialLink("instagram", url: "https://instagram.com/testuser")
        try userProfile.addSocialLink("twitter", url: "https://twitter.com/testuser")
        
        XCTAssertEqual(userProfile.socialLinks.count, 2)
        XCTAssertEqual(userProfile.socialLinks["instagram"], "https://instagram.com/testuser")
        XCTAssertEqual(userProfile.socialLinks["twitter"], "https://twitter.com/testuser")
        
        // Test removing social link
        userProfile.removeSocialLink("instagram")
        XCTAssertEqual(userProfile.socialLinks.count, 1)
        XCTAssertNil(userProfile.socialLinks["instagram"])
        
        // Test adding invalid URL
        XCTAssertThrowsError(try userProfile.addSocialLink("facebook", url: "invalid-url")) { error in
            if case UserProfileError.invalidSocialLink(let platform, let url) = error {
                XCTAssertEqual(platform, "facebook")
                XCTAssertEqual(url, "invalid-url")
            } else {
                XCTFail("Expected UserProfileError.invalidSocialLink")
            }
        }
    }
    
    func testSocialLinksLimit() throws {
        var userProfile = try UserProfile(
            uid: "test-user-123",
            email: "test@example.com",
            displayName: "Test User"
        )
        
        // Add maximum allowed social links
        for i in 1...5 {
            try userProfile.addSocialLink("platform\(i)", url: "https://platform\(i).com/user")
        }
        
        // Adding one more should throw error
        XCTAssertThrowsError(try userProfile.addSocialLink("platform6", url: "https://platform6.com/user")) { error in
            if case UserProfileError.tooManySocialLinks(let count) = error {
                XCTAssertEqual(count, 6)
            } else {
                XCTFail("Expected UserProfileError.tooManySocialLinks")
            }
        }
    }
    
    // MARK: - Interests Tests
    
    func testInterestsManagement() throws {
        var userProfile = try UserProfile(
            uid: "test-user-123",
            email: "test@example.com",
            displayName: "Test User"
        )
        
        // Test adding interests
        try userProfile.addInterest("Music")
        try userProfile.addInterest("Sports")
        try userProfile.addInterest("Technology")
        
        XCTAssertEqual(userProfile.interests.count, 3)
        XCTAssertTrue(userProfile.interests.contains("Music"))
        XCTAssertTrue(userProfile.interests.contains("Sports"))
        XCTAssertTrue(userProfile.interests.contains("Technology"))
        
        // Test removing interest
        userProfile.removeInterest("Sports")
        XCTAssertEqual(userProfile.interests.count, 2)
        XCTAssertFalse(userProfile.interests.contains("Sports"))
        
        // Test adding duplicate interest (should be ignored)
        try userProfile.addInterest("Music")
        XCTAssertEqual(userProfile.interests.count, 2) // Should still be 2
    }
    
    func testInterestsLimit() throws {
        var userProfile = try UserProfile(
            uid: "test-user-123",
            email: "test@example.com",
            displayName: "Test User"
        )
        
        // Add maximum allowed interests
        for i in 1...10 {
            try userProfile.addInterest("Interest \(i)")
        }
        
        // Adding one more should throw error
        XCTAssertThrowsError(try userProfile.addInterest("Interest 11")) { error in
            if case UserProfileError.tooManyInterests(let count) = error {
                XCTAssertEqual(count, 11)
            } else {
                XCTFail("Expected UserProfileError.tooManyInterests")
            }
        }
    }
    
    // MARK: - Privacy Tests
    
    func testPrivacySettings() throws {
        var userProfile = try UserProfile(
            uid: "test-user-123",
            email: "test@example.com",
            displayName: "Test User"
        )
        
        // Test default privacy settings
        XCTAssertTrue(userProfile.isProfilePublic)
        XCTAssertTrue(userProfile.allowsMessagesFromStrangers)
        
        // Test updating privacy settings
        userProfile.isProfilePublic = false
        userProfile.allowsMessagesFromStrangers = false
        
        XCTAssertFalse(userProfile.isProfilePublic)
        XCTAssertFalse(userProfile.allowsMessagesFromStrangers)
    }
    
    // MARK: - Activity Tracking Tests
    
    func testActivityTracking() throws {
        var userProfile = try UserProfile(
            uid: "test-user-123",
            email: "test@example.com",
            displayName: "Test User"
        )
        
        let initialLastActiveAt = userProfile.lastActiveAt
        
        // Update activity
        userProfile.updateLastActiveAt()
        
        // Should be different from initial timestamp
        XCTAssertNotEqual(userProfile.lastActiveAt, initialLastActiveAt)
    }
    
    // MARK: - Profile Completeness Tests
    
    func testProfileCompleteness() throws {
        // Test incomplete profile
        let incompleteProfile = try UserProfile(
            uid: "test-user-123",
            email: "test@example.com",
            displayName: "Test User"
        )
        XCTAssertFalse(incompleteProfile.isComplete)
        
        // Test complete profile
        let completeProfile = try UserProfile(
            uid: "test-user-123",
            email: "test@example.com",
            displayName: "Test User",
            phoneNumber: "+1234567890",
            birthDate: "1990-01-01"
        )
        XCTAssertTrue(completeProfile.isComplete)
    }
    
    // MARK: - Performance Tests
    
    func testUserProfileCreationPerformance() throws {
        measure {
            for _ in 0..<1000 {
                _ = try? UserProfile(
                    uid: "perf-test-user",
                    email: "perf@test.com",
                    displayName: "Performance Test User"
                )
            }
        }
    }
    
    func testInterestsPerformance() throws {
        var userProfile = try UserProfile(
            uid: "test-user-123",
            email: "test@example.com",
            displayName: "Test User"
        )
        
        measure {
            for i in 0..<100 {
                try? userProfile.addInterest("Interest \(i)")
                userProfile.removeInterest("Interest \(i)")
            }
        }
    }
}