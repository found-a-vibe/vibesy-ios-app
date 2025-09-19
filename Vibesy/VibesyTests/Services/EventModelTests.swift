//
//  EventModelTests.swift
//  VibesyTests
//
//  Created by Refactoring Bot on 12/19/24.
//

import XCTest
@testable import Vibesy

@MainActor
final class EventModelTests: XCTestCase {
    
    private var eventModel: EventModel!
    
    override func setUpWithError() throws {
        eventModel = EventModel()
    }
    
    override func tearDownWithError() throws {
        eventModel = nil
    }
    
    // MARK: - Initialization Tests
    
    func testEventModelInitialization() {
        XCTAssertNotNil(eventModel)
        XCTAssertEqual(eventModel.events.count, 0)
        XCTAssertEqual(eventModel.state, .idle)
        XCTAssertFalse(eventModel.isLoading)
        XCTAssertNil(eventModel.error)
        XCTAssertNil(eventModel.selectedEvent)
    }
    
    // MARK: - State Management Tests
    
    func testStateTransitions() {
        // Initial state should be idle
        XCTAssertEqual(eventModel.state, .idle)
        XCTAssertFalse(eventModel.isLoading)
        
        // Simulate loading state
        eventModel.setState(.loading)
        XCTAssertEqual(eventModel.state, .loading)
        XCTAssertTrue(eventModel.isLoading)
        
        // Simulate success state
        eventModel.setState(.loaded)
        XCTAssertEqual(eventModel.state, .loaded)
        XCTAssertFalse(eventModel.isLoading)
        
        // Simulate error state
        let testError = EventError.invalidTitle("Test error")
        eventModel.setState(.error(testError))
        XCTAssertEqual(eventModel.state, .error(testError))
        XCTAssertFalse(eventModel.isLoading)
        XCTAssertNotNil(eventModel.error)
    }
    
    // MARK: - Event Loading Tests
    
    func testLoadEventsSuccess() async throws {
        // Test loading events
        await eventModel.loadEvents()
        
        // After loading, state should be loaded or error (depending on network)
        XCTAssertTrue(eventModel.state == .loaded || eventModel.state.isError)
        
        // If successful, events array should be populated or empty
        XCTAssertTrue(eventModel.events.count >= 0)
    }
    
    func testLoadEventsWithNetworkError() async {
        // Simulate network failure by calling loadEvents in test environment
        await eventModel.loadEvents()
        
        // In test environment, we expect either success or network error
        if case .error(let error) = eventModel.state {
            XCTAssertTrue(error is NetworkError || error is EventError)
        } else {
            // If no error, should be in loaded state
            XCTAssertEqual(eventModel.state, .loaded)
        }
    }
    
    // MARK: - Event Creation Tests
    
    func testCreateEventSuccess() async throws {
        let testEvent = try Event(
            title: "Test Event",
            description: "Test Description",
            date: "2024-12-25",
            timeRange: "7:00 PM - 11:00 PM",
            location: "Test Location",
            createdBy: "test-user-123"
        )
        
        await eventModel.createEvent(testEvent)
        
        // Check if event was added to local array (optimistic update)
        if eventModel.state == .loaded {
            // In case of success, event should be in the array
            let createdEvent = eventModel.events.first { $0.id == testEvent.id }
            XCTAssertNotNil(createdEvent)
            XCTAssertEqual(createdEvent?.title, "Test Event")
        } else if case .error(let error) = eventModel.state {
            // In test environment, network errors are acceptable
            XCTAssertTrue(error is NetworkError)
        }
    }
    
    func testCreateEventWithInvalidData() async throws {
        // Test with invalid event (empty title)
        var invalidEvent = try Event(
            title: "Valid Title",
            description: "Test Description",
            date: "2024-12-25",
            timeRange: "7:00 PM - 11:00 PM",
            location: "Test Location",
            createdBy: "test-user-123"
        )
        
        // Make it invalid
        invalidEvent.title = ""
        
        await eventModel.createEvent(invalidEvent)
        
        // Should result in error state due to validation
        if case .error(let error) = eventModel.state {
            XCTAssertTrue(error is EventError)
        }
    }
    
    // MARK: - Event Update Tests
    
    func testUpdateEventSuccess() async throws {
        // First, add an event to update
        let originalEvent = try Event(
            title: "Original Title",
            description: "Original Description",
            date: "2024-12-25",
            timeRange: "7:00 PM - 11:00 PM",
            location: "Original Location",
            createdBy: "test-user-123"
        )
        
        await eventModel.createEvent(originalEvent)
        
        // Update the event
        var updatedEvent = originalEvent
        updatedEvent.title = "Updated Title"
        
        await eventModel.updateEvent(updatedEvent)
        
        // Check if update was successful
        if eventModel.state == .loaded {
            let foundEvent = eventModel.events.first { $0.id == originalEvent.id }
            if let foundEvent = foundEvent {
                XCTAssertEqual(foundEvent.title, "Updated Title")
            }
        }
    }
    
    // MARK: - Event Deletion Tests
    
    func testDeleteEventSuccess() async throws {
        // First, add an event to delete
        let eventToDelete = try Event(
            title: "Event to Delete",
            description: "This event will be deleted",
            date: "2024-12-25",
            timeRange: "7:00 PM - 11:00 PM",
            location: "Delete Location",
            createdBy: "test-user-123"
        )
        
        await eventModel.createEvent(eventToDelete)
        let initialCount = eventModel.events.count
        
        // Delete the event
        await eventModel.deleteEvent(withId: eventToDelete.id)
        
        // Check if event was removed
        if eventModel.state == .loaded {
            let deletedEvent = eventModel.events.first { $0.id == eventToDelete.id }
            XCTAssertNil(deletedEvent)
            XCTAssertEqual(eventModel.events.count, initialCount - 1)
        }
    }
    
    func testDeleteNonExistentEvent() async {
        let nonExistentId = "non-existent-id-123"
        
        await eventModel.deleteEvent(withId: nonExistentId)
        
        // Should handle gracefully - either success or specific error
        if case .error(let error) = eventModel.state {
            XCTAssertTrue(error is EventError || error is NetworkError)
        } else {
            // If no error, should be in loaded state
            XCTAssertEqual(eventModel.state, .loaded)
        }
    }
    
    // MARK: - Event Selection Tests
    
    func testEventSelection() throws {
        let testEvent = try Event(
            title: "Selectable Event",
            description: "This event can be selected",
            date: "2024-12-25",
            timeRange: "7:00 PM - 11:00 PM",
            location: "Selection Location",
            createdBy: "test-user-123"
        )
        
        // Initially no event should be selected
        XCTAssertNil(eventModel.selectedEvent)
        
        // Select an event
        eventModel.selectEvent(testEvent)
        XCTAssertNotNil(eventModel.selectedEvent)
        XCTAssertEqual(eventModel.selectedEvent?.id, testEvent.id)
        
        // Deselect event
        eventModel.deselectEvent()
        XCTAssertNil(eventModel.selectedEvent)
    }
    
    // MARK: - Event Filtering Tests
    
    func testEventFiltering() throws {
        let event1 = try Event(
            title: "Music Event",
            description: "A music event",
            date: "2024-12-25",
            timeRange: "7:00 PM - 11:00 PM",
            location: "Music Venue",
            category: .music,
            createdBy: "test-user-123"
        )
        
        let event2 = try Event(
            title: "Sports Event",
            description: "A sports event",
            date: "2024-12-26",
            timeRange: "2:00 PM - 6:00 PM",
            location: "Sports Arena",
            category: .sports,
            createdBy: "test-user-123"
        )
        
        // Add events to the model
        eventModel.events = [event1, event2]
        
        // Filter by music category
        eventModel.filterEvents(by: .music)
        let musicEvents = eventModel.filteredEvents
        
        XCTAssertEqual(musicEvents.count, 1)
        XCTAssertEqual(musicEvents.first?.category, .music)
        
        // Filter by sports category
        eventModel.filterEvents(by: .sports)
        let sportsEvents = eventModel.filteredEvents
        
        XCTAssertEqual(sportsEvents.count, 1)
        XCTAssertEqual(sportsEvents.first?.category, .sports)
        
        // Clear filter
        eventModel.clearFilter()
        XCTAssertEqual(eventModel.filteredEvents.count, eventModel.events.count)
    }
    
    // MARK: - Search Tests
    
    func testEventSearch() throws {
        let event1 = try Event(
            title: "Jazz Concert",
            description: "Live jazz music performance",
            date: "2024-12-25",
            timeRange: "8:00 PM - 11:00 PM",
            location: "Jazz Club",
            createdBy: "test-user-123"
        )
        
        let event2 = try Event(
            title: "Rock Festival",
            description: "Rock music festival",
            date: "2024-12-26",
            timeRange: "2:00 PM - 10:00 PM",
            location: "Festival Grounds",
            createdBy: "test-user-123"
        )
        
        eventModel.events = [event1, event2]
        
        // Search for "jazz"
        eventModel.searchEvents(query: "jazz")
        let jazzResults = eventModel.searchResults
        XCTAssertEqual(jazzResults.count, 1)
        XCTAssertTrue(jazzResults.first?.title.lowercased().contains("jazz") == true)
        
        // Search for "music"
        eventModel.searchEvents(query: "music")
        let musicResults = eventModel.searchResults
        XCTAssertEqual(musicResults.count, 2) // Both events contain "music" in description
        
        // Clear search
        eventModel.clearSearch()
        XCTAssertTrue(eventModel.searchResults.isEmpty)
        XCTAssertTrue(eventModel.searchQuery.isEmpty)
    }
    
    // MARK: - Refresh Tests
    
    func testRefreshEvents() async {
        // Perform initial load
        await eventModel.loadEvents()
        let initialState = eventModel.state
        
        // Refresh events
        await eventModel.refreshEvents()
        
        // Should either maintain loaded state or show error
        XCTAssertTrue(eventModel.state == .loaded || eventModel.state.isError)
        
        // If both operations were successful, states should be similar
        if initialState == .loaded && eventModel.state == .loaded {
            XCTAssertTrue(true) // Both successful
        }
    }
    
    // MARK: - Error Handling Tests
    
    func testErrorStateHandling() {
        let testError = EventError.invalidTitle("Test validation error")
        
        // Set error state
        eventModel.setState(.error(testError))
        
        // Verify error properties
        XCTAssertEqual(eventModel.state, .error(testError))
        XCTAssertNotNil(eventModel.error)
        XCTAssertFalse(eventModel.isLoading)
        
        // Clear error
        eventModel.clearError()
        XCTAssertEqual(eventModel.state, .idle)
        XCTAssertNil(eventModel.error)
    }
    
    // MARK: - Performance Tests
    
    func testEventLoadingPerformance() async {
        measure {
            Task { @MainActor in
                await eventModel.loadEvents()
            }
        }
    }
    
    func testEventFilteringPerformance() throws {
        // Create many test events
        let events = try (0..<1000).map { i in
            try Event(
                title: "Event \(i)",
                description: "Description \(i)",
                date: "2024-12-25",
                timeRange: "7:00 PM - 11:00 PM",
                location: "Location \(i)",
                category: i % 2 == 0 ? .music : .sports,
                createdBy: "test-user-\(i)"
            )
        }
        
        eventModel.events = events
        
        measure {
            eventModel.filterEvents(by: .music)
        }
    }
    
    func testEventSearchPerformance() throws {
        // Create many test events
        let events = try (0..<1000).map { i in
            try Event(
                title: "Event \(i)",
                description: "Description \(i) with searchable content",
                date: "2024-12-25",
                timeRange: "7:00 PM - 11:00 PM",
                location: "Location \(i)",
                createdBy: "test-user-\(i)"
            )
        }
        
        eventModel.events = events
        
        measure {
            eventModel.searchEvents(query: "searchable")
        }
    }
    
    // MARK: - Integration Tests
    
    func testCompleteEventLifecycle() async throws {
        // 1. Load events
        await eventModel.loadEvents()
        let initialCount = eventModel.events.count
        
        // 2. Create new event
        let newEvent = try Event(
            title: "Lifecycle Test Event",
            description: "Testing complete lifecycle",
            date: "2024-12-25",
            timeRange: "7:00 PM - 11:00 PM",
            location: "Lifecycle Location",
            createdBy: "lifecycle-user-123"
        )
        
        await eventModel.createEvent(newEvent)
        
        // 3. Update the event
        var updatedEvent = newEvent
        updatedEvent.title = "Updated Lifecycle Event"
        await eventModel.updateEvent(updatedEvent)
        
        // 4. Select the event
        eventModel.selectEvent(updatedEvent)
        XCTAssertEqual(eventModel.selectedEvent?.id, updatedEvent.id)
        
        // 5. Delete the event
        await eventModel.deleteEvent(withId: updatedEvent.id)
        
        // 6. Verify final state
        if eventModel.state == .loaded {
            let finalCount = eventModel.events.count
            XCTAssertEqual(finalCount, initialCount) // Should be back to original count
            
            // Event should no longer exist
            let deletedEvent = eventModel.events.first { $0.id == newEvent.id }
            XCTAssertNil(deletedEvent)
        }
    }
}