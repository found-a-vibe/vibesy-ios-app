//
//  FirebaseEventService.swift
//  Vibesy
//
//  Created by Alexander Cleoni on 12/15/24.
//
import SwiftUI
import Firebase
import FirebaseFirestore
import FirebaseStorage

class FirebaseEventService: EventService, @unchecked Sendable {
    let eventMetaDataManager: FirebaseEventMetaDataManager = FirebaseEventMetaDataManager()
    let interactionManager: InteractionManager = InteractionManager()
    
    @discardableResult
    func createOrUpdateEvent(_ event: Event) async throws -> Event {
        // Base payload (immutable)
        var base: [String: Any] = [
            "id": event.id.uuidString,
            "title": event.title,
            "description": event.description,
            "date": event.date,
            "timeRange": event.timeRange,
            "location": event.location,
            "hashtags": Array(event.hashtags),
            "guests": event.guests.map { ["id": $0.id.uuidString, "name": $0.name] },
            "priceDetails": event.priceDetails.map { priceDetail in
                var dict: [String: Any] = [
                    "id": priceDetail.id.uuidString,
                    "title": priceDetail.title,
                    "price": NSDecimalNumber(decimal: priceDetail.price).doubleValue,
                    "currency": priceDetail.currency.rawValue,
                    "type": priceDetail.type.rawValue
                ]
                if let stripePriceId = priceDetail.stripePriceId {
                    dict["stripePriceId"] = stripePriceId
                }
                return dict
            },
            "likes": Array(event.likes),
            "createdBy": event.createdBy,
//            "category": event.category ?? "N/A"
        ]
        
        // Add Stripe product information if available
        if let stripeProductId = event.stripeProductId {
            base["stripeProductId"] = stripeProductId
        }
        if let stripeConnectedAccountId = event.stripeConnectedAccountId {
            base["stripeConnectedAccountId"] = stripeConnectedAccountId
        }

        // Run heavy work in parallel
        async let guestsDict: [String: Any] = Self.uploadGuestsAndBuildDict(for: event)

        // Image task: upload if new, otherwise reuse existing
        let imagesTask = Task<[String], Error> {
            if !event.newImages.isEmpty {
                // your async uploader; should avoid capturing UIImage across executors
                return try await FirebaseEventImageManager.uploadImages(images: event.newImages,
                                                                        folder: "event_images/\(event.id.uuidString.lowercased())",
                                                                       id: event.id)
            } else {
                return event.images
            }
        }

        // Wait for both
        let (guests, imageURLs) = try await (guestsDict, imagesTask.value)

        // Final payload
        var payload = base.merging(guests, uniquingKeysWith: { _, new in new })
        payload["images"] = imageURLs

        // Persist
        try await eventMetaDataManager.createOrUpdateEventAsync(
            eventId: event.id.uuidString,
            createdByUid: event.createdBy,
            eventDict: payload
        )

        // Return updated model with image URLs
        var updatedEvent = event
        updatedEvent.setImageURLs(imageURLs)
        return updatedEvent
    }
    
    func deleteEvent(eventId: String, createdByUid: String) async throws {
        try await eventMetaDataManager.deleteEventAsync(eventId: eventId, createdByUid: createdByUid)
        try await FirebaseEventImageManager.deleteImagesAsync(eventId: eventId)
    }
    
    func getEventFeed(uid: String) async throws -> [Event] {
        return try await withCheckedThrowingContinuation { continuation in
            getEventFeed(uid: uid) { result in
                continuation.resume(with: result)
            }
        }
    }
    
    func getEventFeed(uid: String, completion: @escaping @MainActor (Result<[Event], Error>) -> Void) {
        eventMetaDataManager.getAllEvents(uid: uid) { result in
            switch result {
            case .success(let events):
                guard !events.isEmpty else {
                    // hop to a Task to call the @MainActor completion
                    Task { await completion(.success([])) }
                    return
                }
                
                Task {
                    do {
                        let ids  = events.map { $0.id.uuidString }
                        let dict = try await FirebaseEventImageManager
                            .retrieveImagesForEventIds(ids)
                        
                        // Merge image URLs with events
                        let updated: [Event] = events.compactMap { event in
                            var updatedEvent = event
                            if let imageUrls = dict[event.id.uuidString] {
                                updatedEvent.setImageURLs(imageUrls)
                            }
                            return updatedEvent
                        }
                        
                        await completion(.success(updated))
                    } catch {
                        await completion(.failure(error))
                    }
                }
                
            case .failure(let error):
                Task { await completion(.failure(error)) }
            }
        }
    }
    
    func getEventsByStatus(uid: String, status: EventStatus) async throws -> [Event] {
        return try await withCheckedThrowingContinuation { continuation in
            getEventsByStatus(uid: uid, status: status) { result in
                continuation.resume(with: result)
            }
        }
    }
    
    func getEventsByStatus(uid: String, status: EventStatus, completion: @escaping @MainActor (Result<[Event], Error>) -> Void) {
        eventMetaDataManager.getEventsByStatus(uid: uid, status: status) { result in
            switch result {
            case .success(let events):
                guard !events.isEmpty else {
                    Task { await completion(.success([])) }
                    return
                }

                Task {
                    do {
                        let ids  = events.map { $0.id.uuidString }
                        // async version that returns [eventId: [url]]
                        let dict = try await FirebaseEventImageManager.retrieveImagesForEventIds(ids)

                        // Merge image URLs with events
                        let updated: [Event] = events.compactMap { event in
                            var updatedEvent = event
                            if let imageUrls = dict[event.id.uuidString] {
                                updatedEvent.setImageURLs(imageUrls)
                            }
                            return updatedEvent
                        }

                        await completion(.success(updated))
                    } catch {
                        await completion(.failure(error))
                    }
                }

            case .failure(let error):
                Task { await completion(.failure(error)) }
            }
        }
    }
    
    // MARK: - Like/Unlike Methods
    func likeEvent(eventId: String, userID: String) async throws {
        // Use InteractionManager which handles the complete like flow
        // including updating user's likedEvents and event's likes/interactions
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            interactionManager.likeEvent(uid: userID, eventId: eventId) { error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
        }
    }
    
    func unlikeEvent(eventId: String, userID: String) async throws {
        // Use InteractionManager which handles the complete unlike flow
        // including updating user's likedEvents and event's likes/interactions
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            interactionManager.unlikeEvent(uid: userID, eventId: eventId) { error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
        }
    }
}

extension FirebaseEventService {
    private static func uploadGuestsAndBuildDict(
        for event: Event,
    ) async throws -> [String: Any] {
        let guests = event.guests
        guard !guests.isEmpty else { return [:] }
        
        // Convert guests to dictionary format (no image upload since Guest model doesn't have UIImage)
        let guestsDictArray = guests.map { guest in
            [
                "id": guest.id.uuidString,
                "name": guest.name,
                "role": guest.role,
                "imageUrl": guest.imageUrl ?? ""
            ]
        }
        
        return ["guests": guestsDictArray]
    }
}

private extension FirebaseEventMetaDataManager {
    func deleteEventAsync(eventId: String, createdByUid: String) async throws {
        try await withCheckedThrowingContinuation { cont in
            deleteEvent(eventId: eventId, createdByUid: createdByUid) { result in
                switch result {
                case .success:        cont.resume()
                case .failure(let e): cont.resume(throwing: e)
                }
            }
        }
    }
}
