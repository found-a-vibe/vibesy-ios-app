//
//  EventTests.swift
//  VibesyTests
//
//  Created by Refactoring Bot on 12/19/24.
//

import XCTest
@testable import Vibesy

final class EventTests: XCTestCase {
    
    override func setUpWithError() throws {
        // Setup code here
    }
    
    override func tearDownWithError() throws {
        // Cleanup code here
    }
    
    // MARK: - Event Creation Tests
    
    func testEventCreationSuccess() throws {
        let event = try Event(
            title: "Test Event",
            description: "This is a test event",
            date: "2024-12-25",
            timeRange: "7:00 PM - 11:00 PM",
            location: "Test Location",
            category: .music,
            createdBy: "test-user-id"
        )
        
        XCTAssertEqual(event.title, "Test Event")
        XCTAssertEqual(event.description, "This is a test event")
        XCTAssertEqual(event.date, "2024-12-25")
        XCTAssertEqual(event.timeRange, "7:00 PM - 11:00 PM")
        XCTAssertEqual(event.location, "Test Location")
        XCTAssertEqual(event.category, .music)
        XCTAssertEqual(event.createdBy, "test-user-id")
        XCTAssertTrue(event.isComplete)
    }
    
    func testEventCreationWithEmptyCreatedBy() {
        XCTAssertThrowsError(try Event(
            title: "Test Event",
            description: "This is a test event",
            date: "2024-12-25",
            timeRange: "7:00 PM - 11:00 PM",
            location: "Test Location",
            createdBy: ""
        )) { error in
            XCTAssertTrue(error is EventError)
            if case EventError.invalidCreatorUID(let uid) = error {
                XCTAssertEqual(uid, "")
            } else {
                XCTFail("Expected EventError.invalidCreatorUID")
            }
        }
    }
    
    // MARK: - Event Validation Tests
    
    func testEventValidation() throws {
        var event = try Event(
            title: "Test Event",
            description: "This is a test event",
            date: "2024-12-25",
            timeRange: "7:00 PM - 11:00 PM",
            location: "Test Location",
            createdBy: "test-user-id"
        )
        
        // Should validate successfully
        XCTAssertNoThrow(try event.validate())
        
        // Test invalid title (empty)
        event.title = ""
        XCTAssertThrowsError(try event.validate()) { error in
            XCTAssertTrue(error is EventError)
        }
    }
    
    func testEventTitleValidation() throws {
        var event = try Event(
            title: "Test Event",
            description: "This is a test event",
            date: "2024-12-25",
            timeRange: "7:00 PM - 11:00 PM",
            location: "Test Location",
            createdBy: "test-user-id"
        )
        
        // Test title length limits
        let longTitle = String(repeating: "a", count: 101)
        event.title = longTitle
        XCTAssertThrowsError(try event.validate()) { error in
            if case EventError.invalidTitle(_) = error {
                // Expected error
            } else {
                XCTFail("Expected EventError.invalidTitle")
            }
        }
    }
    
    // MARK: - Hashtag Tests
    
    func testHashtagManagement() throws {
        var event = try Event(
            title: "Test Event",
            description: "This is a test event",
            date: "2024-12-25",
            timeRange: "7:00 PM - 11:00 PM",
            location: "Test Location",
            createdBy: "test-user-id"
        )
        
        // Test adding hashtag
        try event.addHashtag("music")
        XCTAssertEqual(event.hashtags, ["#music"])
        
        // Test adding hashtag with # prefix
        try event.addHashtag("#dance")
        XCTAssertEqual(event.hashtags.count, 2)
        XCTAssertTrue(event.hashtags.contains("#dance"))
        
        // Test removing hashtag
        event.removeHashtag("#music")
        XCTAssertFalse(event.hashtags.contains("#music"))
        XCTAssertTrue(event.hashtags.contains("#dance"))
    }
    
    func testHashtagLimits() throws {
        var event = try Event(
            title: "Test Event",
            description: "This is a test event",
            date: "2024-12-25",
            timeRange: "7:00 PM - 11:00 PM",
            location: "Test Location",
            createdBy: "test-user-id"
        )
        
        // Add maximum allowed hashtags
        for i in 1...10 {
            try event.addHashtag("tag\(i)")
        }
        
        // Adding one more should throw error
        XCTAssertThrowsError(try event.addHashtag("tag11")) { error in
            if case EventError.tooManyHashtags(let count) = error {
                XCTAssertEqual(count, 11)
            } else {
                XCTFail("Expected EventError.tooManyHashtags")
            }
        }
    }
    
    // MARK: - Guest Management Tests
    
    func testGuestManagement() throws {
        var event = try Event(
            title: "Test Event",
            description: "This is a test event",
            date: "2024-12-25",
            timeRange: "7:00 PM - 11:00 PM",
            location: "Test Location",
            createdBy: "test-user-id"
        )
        
        let guest = try Guest(name: "Test Guest", role: .speaker)
        
        // Test adding guest
        try event.addGuest(guest)
        XCTAssertEqual(event.guestCount, 1)
        XCTAssertEqual(event.guests.first?.name, "Test Guest")
        
        // Test adding duplicate guest
        XCTAssertThrowsError(try event.addGuest(guest)) { error in
            if case EventError.duplicateGuest(_) = error {
                // Expected error
            } else {
                XCTFail("Expected EventError.duplicateGuest")
            }
        }
        
        // Test removing guest
        try event.removeGuest(byId: guest.id)
        XCTAssertEqual(event.guestCount, 0)
        
        // Test removing non-existent guest
        XCTAssertThrowsError(try event.removeGuest(byId: guest.id)) { error in
            if case EventError.guestNotFound(_) = error {
                // Expected error
            } else {
                XCTFail("Expected EventError.guestNotFound")
            }
        }
    }
    
    // MARK: - Image Management Tests
    
    func testImageManagement() throws {
        var event = try Event(
            title: "Test Event",
            description: "This is a test event",
            date: "2024-12-25",
            timeRange: "7:00 PM - 11:00 PM",
            location: "Test Location",
            createdBy: "test-user-id"
        )
        
        // Test adding image URLs
        try event.addImageURL("https://example.com/image1.jpg")
        try event.addImageURL("https://example.com/image2.jpg")
        
        XCTAssertEqual(event.images.count, 2)
        XCTAssertTrue(event.images.contains("https://example.com/image1.jpg"))
        
        // Test adding duplicate URL (should be ignored)
        try event.addImageURL("https://example.com/image1.jpg")
        XCTAssertEqual(event.images.count, 2) // Should still be 2
        
        // Test removing image
        event.removeImageURL("https://example.com/image1.jpg")
        XCTAssertEqual(event.images.count, 1)
        XCTAssertFalse(event.images.contains("https://example.com/image1.jpg"))
    }
    
    // MARK: - Interaction Tests
    
    func testLikeInteractions() throws {
        var event = try Event(
            title: "Test Event",
            description: "This is a test event",
            date: "2024-12-25",
            timeRange: "7:00 PM - 11:00 PM",
            location: "Test Location",
            createdBy: "test-user-id"
        )
        
        let userId = "user-123"
        
        // Test adding like
        event.addLike(from: userId)
        XCTAssertEqual(event.likeCount, 1)
        XCTAssertTrue(event.isLikedBy(userId))
        
        // Test removing like
        event.removeLike(from: userId)
        XCTAssertEqual(event.likeCount, 0)
        XCTAssertFalse(event.isLikedBy(userId))
    }
    
    func testReservationInteractions() throws {
        var event = try Event(
            title: "Test Event",
            description: "This is a test event",
            date: "2024-12-25",
            timeRange: "7:00 PM - 11:00 PM",
            location: "Test Location",
            createdBy: "test-user-id"
        )
        
        let userId = "user-123"
        
        // Test adding reservation
        event.addReservation(from: userId)
        XCTAssertEqual(event.reservationCount, 1)
        XCTAssertTrue(event.isReservedBy(userId))
        
        // Test removing reservation
        event.removeReservation(from: userId)
        XCTAssertEqual(event.reservationCount, 0)
        XCTAssertFalse(event.isReservedBy(userId))
    }
    
    // MARK: - Performance Tests
    
    func testEventCreationPerformance() throws {
        measure {
            for _ in 0..<1000 {
                _ = try? Event(
                    title: "Performance Test Event",
                    description: "This is a performance test",
                    date: "2024-12-25",
                    timeRange: "7:00 PM - 11:00 PM",
                    location: "Performance Location",
                    createdBy: "perf-user-id"
                )
            }
        }
    }
    
    func testHashtagPerformance() throws {
        var event = try Event(
            title: "Test Event",
            description: "This is a test event",
            date: "2024-12-25",
            timeRange: "7:00 PM - 11:00 PM",
            location: "Test Location",
            createdBy: "test-user-id"
        )
        
        measure {
            for i in 0..<100 {
                try? event.addHashtag("tag\(i)")
                event.removeHashtag("#tag\(i)")
            }
        }
    }
}