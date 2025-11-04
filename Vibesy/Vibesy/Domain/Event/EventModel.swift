//
//  EventModel.swift
//  Vibesy
//
//  Created by Alexander Cleoni on 12/15/24.
//

import Foundation
import UIKit
import os.log

// MARK: - Event Model Errors
enum EventModelError: LocalizedError {
    case noEventToCreate
    case noEventToUpdate
    case noEventToDelete
    case eventNotFound(UUID)
    case invalidUserID(String)
    case serviceFailed(Error)
    
    var errorDescription: String? {
        switch self {
        case .noEventToCreate:
            return "No event data available to create."
        case .noEventToUpdate:
            return "No event selected to update."
        case .noEventToDelete:
            return "No event selected for deletion."
        case .eventNotFound(let id):
            return "Event with ID \(id) not found."
        case .invalidUserID(let id):
            return "Invalid user ID: \(id)."
        case .serviceFailed(let error):
            return "Service operation failed: \(error.localizedDescription)"
        }
    }
}

// MARK: - Event Loading State
enum EventLoadingState: Equatable {
    case idle
    case loading
    case success
    case failure(String)
    
    var isLoading: Bool {
        if case .loading = self {
            return true
        }
        return false
    }
    
    var errorMessage: String? {
        if case .failure(let message) = self {
            return message
        }
        return nil
    }
}

@MainActor
final class EventModel: ObservableObject {
    private static let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "Vibesy", category: "EventModel")
    
    // MARK: - Published Properties
    @Published private(set) var events: [Event] = []
    @Published private(set) var likedEvents: [Event] = []
    @Published private(set) var postedEvents: [Event] = []
    @Published private(set) var reservedEvents: [Event] = []
    @Published private(set) var attendedEvents: [Event] = []
    @Published var newEvent: Event?
    @Published private(set) var currentEventDetails: Event?
    @Published private(set) var loadingState: EventLoadingState = .idle
    @Published var buttonSwipeAction: Action?
    
    // MARK: - Computed Properties
    var isLoading: Bool {
        loadingState.isLoading
    }
    
    var errorMessage: String? {
        loadingState.errorMessage
    }
    
    var hasEvents: Bool {
        !events.isEmpty
    }
    
    var eventCount: Int {
        events.count
    }
    
    // MARK: - Private Properties
    private let service: EventService
    
    // MARK: - Initialization
    init(service: EventService) {
        self.service = service
        Self.logger.info("EventModel initialized")
    }
    
    // MARK: - Event Creation
    func createNewEvent(userId: String) throws {
        guard !userId.isEmpty else {
            throw EventModelError.invalidUserID(userId)
        }
        
        // Use the empty Event initializer to avoid validation errors
        newEvent = Event.empty(createdBy: userId)
        Self.logger.debug("New event created for user: \(userId)")
    }
    
    func clearNewEvent() {
        newEvent = nil
        Self.logger.debug("New event cleared")
    }
    
    // MARK: - Event Operations
    func addEvent(guestImages: [UUID: UIImage] = [:]) async throws {
        guard let eventToAdd = newEvent else {
            throw EventModelError.noEventToCreate
        }
        
        Self.logger.info("Adding event: \(eventToAdd.title)")
        loadingState = .loading
        
        do {
            // Validate event before adding
            try eventToAdd.validate()
            
            let createdEvent = try await service.createOrUpdateEvent(eventToAdd, guestImages: guestImages)
            
            // Update UI on main actor
            events.append(createdEvent)
            postedEvents.append(createdEvent)
            newEvent = nil
            loadingState = .success
            
            Self.logger.info("Event added successfully: \(createdEvent.id)")
            
        } catch {
            let errorMsg = "Failed to add event: \(error.localizedDescription)"
            loadingState = .failure(errorMsg)
            Self.logger.error("\(errorMsg)")
            throw EventModelError.serviceFailed(error)
        }
    }
    
    func updateEvent(_ event: Event, guestImages: [UUID: UIImage] = [:]) async throws {
        Self.logger.info("Updating event: \(event.id)")
        loadingState = .loading
        
        do {
            // Validate event before updating
            try event.validate()
            
            let updatedEvent = try await service.createOrUpdateEvent(event, guestImages: guestImages)
            
            // Update in all relevant arrays
            updateEventInArrays(updatedEvent)
            loadingState = .success
            
            Self.logger.info("Event updated successfully: \(updatedEvent.id)")
            
        } catch {
            let errorMsg = "Failed to update event: \(error.localizedDescription)"
            loadingState = .failure(errorMsg)
            Self.logger.error("\(errorMsg)")
            throw EventModelError.serviceFailed(error)
        }
    }
    
    func deleteEvent(_ event: Event) async throws {
        Self.logger.info("Deleting event: \(event.id)")
        loadingState = .loading
        
        do {
            try await service.deleteEvent(eventId: event.id.uuidString, createdByUid: event.createdBy)
            
            // Remove from all arrays
            removeEventFromAllArrays(event)
            
            // Clear current details if it's the deleted event
            if currentEventDetails?.id == event.id {
                currentEventDetails = nil
            }
            
            loadingState = .success
            Self.logger.info("Event deleted successfully: \(event.id)")
            
        } catch {
            let errorMsg = "Failed to delete event: \(error.localizedDescription)"
            loadingState = .failure(errorMsg)
            Self.logger.error("\(errorMsg)")
            throw EventModelError.serviceFailed(error)
        }
    }
    
    func deleteCurrentEvent() async throws {
        guard let eventToDelete = currentEventDetails else {
            throw EventModelError.noEventToDelete
        }
        
        try await deleteEvent(eventToDelete)
    }
    
    // MARK: - Fetching Events
    func fetchEventFeed(uid: String) async {
        guard !uid.isEmpty else {
            loadingState = .failure("Invalid user ID")
            return
        }
        
        Self.logger.info("Fetching event feed for user: \(uid)")
        loadingState = .loading
        
        do {
            let fetchedEvents = try await service.getEventFeed(uid: uid)
            events = fetchedEvents
            loadingState = .success
            
            Self.logger.info("Event feed fetched successfully: \(fetchedEvents.count) events")
            
        } catch {
            let errorMsg = "Failed to fetch event feed: \(error.localizedDescription)"
            loadingState = .failure(errorMsg)
            Self.logger.error("\(errorMsg)")
        }
    }
    
    func getEventsByStatus(uid: String, status: EventStatus) async {
        guard !uid.isEmpty else {
            loadingState = .failure("Invalid user ID")
            return
        }
        
        Self.logger.info("Fetching events by status: \(status.rawValue) for user: \(uid)")
        loadingState = .loading
        
        do {
            let fetchedEvents = try await service.getEventsByStatus(uid: uid, status: status)
            updateEvents(for: status, events: fetchedEvents)
            loadingState = .success
            
            Self.logger.info("Events by status fetched successfully: \(fetchedEvents.count) events")
            
        } catch {
            let errorMsg = "Failed to fetch events by status: \(error.localizedDescription)"
            loadingState = .failure(errorMsg)
            Self.logger.error("\(errorMsg)")
        }
    }
    
    // MARK: - Event Interactions
    func likeEvent(_ event: Event, userID: String) async throws {
        guard !userID.isEmpty else {
            throw EventModelError.invalidUserID(userID)
        }
        
        Self.logger.debug("User \(userID) liking event: \(event.id)")
        
        do {
            var updatedEvent = event
            updatedEvent.addLike(from: userID)
            
            // Update the service
            try await service.likeEvent(eventId: event.id.uuidString, userID: userID)
            
            // Update local state
            updateEventInArrays(updatedEvent)
            
            // Add to liked events if not already present
            if !likedEvents.contains(where: { $0.id == event.id }) {
                likedEvents.append(updatedEvent)
            }
            
            Self.logger.info("Event liked successfully")
            
        } catch {
            Self.logger.error("Failed to like event: \(error.localizedDescription)")
            throw EventModelError.serviceFailed(error)
        }
    }
    
    func unlikeEvent(_ event: Event, userID: String) async throws {
        guard !userID.isEmpty else {
            throw EventModelError.invalidUserID(userID)
        }
        
        Self.logger.debug("User \(userID) unliking event: \(event.id)")
        
        do {
            var updatedEvent = event
            updatedEvent.removeLike(from: userID)
            
            // Update the service
            try await service.unlikeEvent(eventId: event.id.uuidString, userID: userID)
            
            // Update local state
            updateEventInArrays(updatedEvent)
            
            // Remove from liked events
            likedEvents.removeAll { $0.id == event.id }
            
            Self.logger.info("Event unliked successfully")
            
        } catch {
            Self.logger.error("Failed to unlike event: \(error.localizedDescription)")
            throw EventModelError.serviceFailed(error)
        }
    }
    
    // MARK: - Event Management
    func removeLikedEvent(_ event: Event) {
        likedEvents.removeAll { $0.id == event.id }
        if currentEventDetails?.id == event.id {
            currentEventDetails = nil
        }
        Self.logger.debug("Liked event removed: \(event.id)")
    }
    
    func removeEventFromFeed(_ event: Event) {
        events.removeAll { $0.id == event.id }
        Self.logger.debug("Event removed from feed: \(event.id)")
    }
    
    func setCurrentEventDetails(_ event: Event) {
        currentEventDetails = event
        Self.logger.debug("Current event details set: \(event.id)")
    }
    
    func clearCurrentEventDetails() {
        currentEventDetails = nil
        Self.logger.debug("Current event details cleared")
    }
    
    // MARK: - Search and Filter
    func searchEvents(query: String) -> [Event] {
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return events
        }
        
        let lowercaseQuery = query.lowercased()
        return events.filter { event in
            event.title.lowercased().contains(lowercaseQuery) ||
            event.description.lowercased().contains(lowercaseQuery) ||
            event.location.lowercased().contains(lowercaseQuery) ||
            event.hashtags.joined().lowercased().contains(lowercaseQuery)
        }
    }
    
//    func filterEventsByCategory(_ category: EventCategory?) -> [Event] {
//        guard let category = category else {
//            return events
//        }
//        
//        return events.filter { $0.category == category }
//    }
    
    // MARK: - Utility Methods
    func getEvent(byId id: UUID) -> Event? {
        return events.first { $0.id == id } ??
               likedEvents.first { $0.id == id } ??
               postedEvents.first { $0.id == id } ??
               reservedEvents.first { $0.id == id } ??
               attendedEvents.first { $0.id == id }
    }
    
    func clearAllEvents() {
        events.removeAll()
        likedEvents.removeAll()
        postedEvents.removeAll()
        reservedEvents.removeAll()
        attendedEvents.removeAll()
        currentEventDetails = nil
        newEvent = nil
        loadingState = .idle
        Self.logger.info("All events cleared")
    }
    
    func clearError() {
        if case .failure = loadingState {
            loadingState = .idle
        }
    }
    
    // MARK: - Private Helper Methods
    private func updateEvents(for status: EventStatus, events: [Event]) {
        switch status {
        case .likedEvents:
            self.likedEvents = events
        case .postedEvents:
            self.postedEvents = events
        case .reservedEvents:
            self.reservedEvents = events
        case .attendedEvents:
            self.attendedEvents = events
        }
    }
    
    private func updateEventInArrays(_ updatedEvent: Event) {
        // Update in main events array
        if let index = events.firstIndex(where: { $0.id == updatedEvent.id }) {
            events[index] = updatedEvent
        }
        
        // Update in liked events
        if let index = likedEvents.firstIndex(where: { $0.id == updatedEvent.id }) {
            likedEvents[index] = updatedEvent
        }
        
        // Update in posted events
        if let index = postedEvents.firstIndex(where: { $0.id == updatedEvent.id }) {
            postedEvents[index] = updatedEvent
        }
        
        // Update in reserved events
        if let index = reservedEvents.firstIndex(where: { $0.id == updatedEvent.id }) {
            reservedEvents[index] = updatedEvent
        }
        
        // Update in attended events
        if let index = attendedEvents.firstIndex(where: { $0.id == updatedEvent.id }) {
            attendedEvents[index] = updatedEvent
        }
        
        // Update current event details if it's the same event
        if currentEventDetails?.id == updatedEvent.id {
            currentEventDetails = updatedEvent
        }
    }
    
    private func removeEventFromAllArrays(_ event: Event) {
        events.removeAll { $0.id == event.id }
        likedEvents.removeAll { $0.id == event.id }
        postedEvents.removeAll { $0.id == event.id }
        reservedEvents.removeAll { $0.id == event.id }
        attendedEvents.removeAll { $0.id == event.id }
    }
}
