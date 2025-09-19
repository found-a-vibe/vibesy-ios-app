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
    
    @discardableResult
    func createOrUpdateEvent(_ event: Event) async throws -> Event {
        // Base payload (immutable)
        let base: [String: Any] = [
            "id": event.id.uuidString,
            "title": event.title,
            "description": event.description,
            "date": event.date,
            "timeRange": event.timeRange,
            "location": event.location,
            "hashtags": Array(event.hashtags),
            "guests": event.guests.map { ["id": $0.id.uuidString, "name": $0.name] },
            "priceDetails": event.priceDetails.map { ["title": $0.title, "price": $0.price] },
            "likes": Array(event.likes),
            "createdBy": event.createdBy,
            "category": event.category ?? "N/A"
        ]

        // Run heavy work in parallel
        async let guestsDict: [String: Any] = Self.uploadGuestsAndBuildDict(for: event)

        // Image task: upload if new, otherwise reuse existing
        let imagesTask = Task<[String], Error> {
            if let newImages = event.newImages, !newImages.isEmpty {
                // your async uploader; should avoid capturing UIImage across executors
                return try await FirebaseEventImageManager.uploadImages(images: newImages,
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

        // Return updated model
        var updated = event
        updated.images = imageURLs
        return updated
    }
    
    func deleteEvent(eventId: String, createdByUid: String) async throws {
        try await eventMetaDataManager.deleteEventAsync(eventId: eventId, createdByUid: createdByUid)
        try await FirebaseEventImageManager.deleteImagesAsync(eventId: eventId)
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
                        
                        let updated: [Event] = events.map { event in
                            var e = event
                            e.images = dict[event.id.uuidString] ?? []
                            return e
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

                        let updated = events.map { event -> Event in
                            var e = event
                            e.images = dict[event.id.uuidString] ?? []
                            return e
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
}

extension FirebaseEventService {
    private static func uploadGuestsAndBuildDict(
        for event: Event,
    ) async throws -> [String: Any] {
        let guests = event.getGuests()
        guard !guests.isEmpty else { return [:] }
        
        // Use a TaskGroup to upload all images in parallel
        let uploadResults: [(index: Int, dict: [String: String])] = try await withThrowingTaskGroup(
            of: (Int, [String: String]).self
        ) { group in
            for (idx, guest) in guests.enumerated() {
                guard let img = guest.image else { continue }
                group.addTask {
                    let urlString = try await FirebaseEventImageManager.uploadImages(
                        images: [img],
                        folder: "guest_speakers",
                        id: guest.id,
                    )
                    let entry: [String: String] = [
                        "id": guest.id.uuidString,
                        "name": guest.name,
                        "role": guest.role,
                        "imageUrl": urlString[0]
                    ]
                    return (idx, entry)
                }
            }
            
            var results = [(Int, [String: String])]()
            for try await result in group {
                results.append(result)
            }
            return results
        }
        
        // Sort by the original index to preserve order
        let sorted = uploadResults
            .sorted { $0.index < $1.index }
            .map { $0.dict }
        
        return ["guests": sorted]
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
