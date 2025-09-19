//
//  EventService.swift
//  FoundAVibe
//
//  Created by Alexander Cleoni on 12/13/24.
//

protocol EventService: Sendable {
    func createOrUpdateEvent(_ event: Event) async throws -> Event 
    func deleteEvent(eventId: String, createdByUid: String) async throws
    func getEventFeed(uid: String, completion: @escaping @MainActor (Result<[Event], Error>) -> Void)
    func getEventsByStatus(uid: String, status: EventStatus, completion: @escaping @MainActor(Result<[Event], Error>) -> Void)
}
