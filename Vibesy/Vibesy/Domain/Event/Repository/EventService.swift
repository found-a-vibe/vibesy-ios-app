//
//  EventService.swift
//  FoundAVibe
//
//  Created by Alexander Cleoni on 12/13/24.
//

protocol EventService: Sendable {
    func createOrUpdateEvent(_ event: Event) async throws -> Event 
    func deleteEvent(eventId: String, createdByUid: String) async throws
    func getEventFeed(uid: String) async throws -> [Event]
    func getEventsByStatus(uid: String, status: EventStatus) async throws -> [Event]
    func likeEvent(eventId: String, userID: String) async throws
    func unlikeEvent(eventId: String, userID: String) async throws
}
