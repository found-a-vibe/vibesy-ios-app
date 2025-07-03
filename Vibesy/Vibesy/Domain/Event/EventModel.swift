//
//  EventModel.swift
//  Vibesy
//
//  Created by Alexander Cleoni on 12/15/24.
//

import Foundation

@MainActor
class EventModel: ObservableObject {
    @Published var events: [Event] = []
    @Published var likedEvents: [Event] = []
    @Published var postedEvents: [Event] = []
    @Published var newEvent: Event? = nil
    @Published var currentEventDetails: Event? = nil
    @Published var errorMessage: String? // UI can observe this to display errors
    @Published var buttonSwipeAction: Action? = nil
    @Published var isLoading: Bool = false
        
    private let service: EventService
    
    init(service: EventService) {
        self.service = service
    }
    
    // Create a new event with default values
    func createNewEvent(userId: String) {
        newEvent = Event(
            id: UUID(),
            title: "",
            description: "",
            date: "",
            timeRange: "",
            location: "",
            createdBy: userId
        )
    }
    
    // Add a new event using the service layer
    func addEvent() {
        guard let newEvent else { return }
        service.createOrUpdateEvent(newEvent) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let updatedEvent):
                    self?.events.append(updatedEvent) // ✅ Use updated event with images
                    self?.errorMessage = nil
                case .failure(let error):
                    self?.errorMessage = error.localizedDescription
                }
            }
        }
    }
    
    // Add a new event using the service layer
    func deleteEvent() {
        guard let currentEventDetails else { return }
        service.deleteEvent(eventId: currentEventDetails.id.uuidString, createdByUid: currentEventDetails.createdBy) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    if let index = self?.events.firstIndex(where: { $0.id.uuidString == currentEventDetails.id.uuidString }) {
                        self?.events.remove(at: index)
                    }
                    self?.errorMessage = nil      // Clear errors
                case .failure(let error):
                    self?.errorMessage = error.localizedDescription
                }
            }
        }
    }
    
    // Fetch event feed and update the state
    func fetchEventFeed(uid: String) {
        service.getEventFeed(uid: uid) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let fetchedEvents):
                    self?.events = fetchedEvents
                case .failure(let error):
                    self?.errorMessage = error.localizedDescription
                }
            }
        }
    }
    
    func getEventsByStatus(uid: String, status: EventStatus) {
        self.isLoading = true
        service.getEventsByStatus(uid: uid, status: status) { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self else { return }
                
                switch result {
                case .success(let fetchedEvents):
                    self.updateEvents(for: status, events: fetchedEvents) // Extract logic into a function
                case .failure(let error):
                    self.errorMessage = error.localizedDescription
                }
                
                self.isLoading = false
            }
        }
    }
    
    // Extracted helper function
    private func updateEvents(for status: EventStatus, events: [Event]) {
        switch status {
        case .likedEvents:
            self.likedEvents = events
        case .postedEvents:
            self.postedEvents = events
        default:
            break
        }
    }
    
    func removeLikedEvent(_ event: Event) {
        self.likedEvents.removeAll { $0.id == event.id }
        self.removeCurrentEventDetails()
    }
    
    func removeEventFromFeed(_ event: Event) {
        events.removeAll { $0.id == event.id }
    }
    
    func setCurrentEventDetails(_ event: Event) {
        self.currentEventDetails = event
    }
    
    func removeCurrentEventDetails() {
        self.currentEventDetails = nil
    }
}
