//
//  EventService.swift
//  FoundAVibe
//
//  Created by Alexander Cleoni on 12/13/24.
//

protocol EventService {
    func createOrUpdateEvent(_ event: Event, completion: @escaping (Result<Event, Error>) -> Void)
    func deleteEvent(eventId: String, createdByUid: String, completion: @escaping (Result<Void, Error>) -> Void)
    func getEventFeed(uid: String, completion: @escaping (Result<[Event], Error>) -> Void)
    func getEventsByStatus(uid: String, status: EventStatus, completion: @escaping (Result<[Event], Error>) -> Void)
}
