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

class FirebaseEventService: EventService {
    let eventImageManager: FirebaseEventImageManager = FirebaseEventImageManager()
    let eventMetaDataManager: FirebaseEventMetaDataManager = FirebaseEventMetaDataManager()
    
    // Submit Event Object to Firestore
    func createOrUpdateEvent(_ event: Event, completion: @escaping (Result<Event, Error>) -> Void) {
        var eventDict: [String: Any] = [
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
            "category": event.category ?? "N/A",
            "images": event.images
        ]
        
        // Function to update event metadata
        func submitEvent(with images: [String]) {
            eventDict["images"] = images
            eventMetaDataManager.createOrUpdateEvent(eventId: event.id.uuidString, createdByUid: event.createdBy, eventDict: eventDict) { result in
                switch result {
                case .success:
                    // Return the updated event with new images
                    var updatedEvent = event
                    updatedEvent.images = images
                    completion(.success(updatedEvent))
                case .failure(let error):
                    completion(.failure(error))
                }
            }
        }
        
        Task {
            do {
                let guestsDict = try await uploadGuestsAndBuildDict(for: event)
                eventDict.merge(guestsDict) { (_, new) in new }
                
                // Upload new images if any, otherwise update event directly
                if let newImages = event.newImages, !newImages.isEmpty {
                    eventImageManager.uploadImages(newImages, folder: "event_images", id: event.id) { imageURLs in
                        submitEvent(with: imageURLs)
                    }
                } else {
                    submitEvent(with: event.images)
                }
            } catch {
                print("Failed to upload guests:", error)
            }
        }
    }
    
    func deleteEvent(eventId: String, createdByUid: String, completion: @escaping (Result<Void, Error>) -> Void) {
        // Step 1: Delete the event metadata first
        eventMetaDataManager.deleteEvent(eventId: eventId, createdByUid: createdByUid) { eventDeletionResult in
            switch eventDeletionResult {
            case .success:
                print("Successfully deleted event metadata for event: \(eventId). Proceeding to delete images.")
                
                // Step 2: Now delete images
                self.eventImageManager.deleteImages(eventId: eventId) { imageDeletionResult in
                    switch imageDeletionResult {
                    case .success:
                        print("Successfully deleted images for event: \(eventId).")
                        completion(.success(()))
                    case .failure(let error):
                        print("Event metadata deleted, but failed to delete images: \(error.localizedDescription)")
                        completion(.failure(error))
                    }
                }
                
            case .failure(let error):
                print("Failed to delete event metadata: \(error.localizedDescription)")
                completion(.failure(error))
            }
        }
    }
    
    func getEventFeed(uid: String, completion: @escaping (Result<[Event], Error>) -> Void) {
        eventMetaDataManager.getAllEvents(uid: uid) { result in
            switch result {
            case .success(let events):
                guard !events.isEmpty else {
                    completion(.success([])) // Return early if no events
                    return
                }
                
                let dispatchGroup = DispatchGroup()
                var eventImagesDict: [String: [String]] = [:] // Store images by eventId
                
                // Get all event IDs
                let eventIds = events.map { $0.id.uuidString }
                
                // Fetch all images in a batch query
                dispatchGroup.enter()
                self.eventImageManager.retrieveImagesForEventIds(eventIds: eventIds) { imagesDict in
                    eventImagesDict = imagesDict
                    dispatchGroup.leave()
                }
                
                // Notify when all async operations complete
                dispatchGroup.notify(queue: .main) {
                    let updatedEvents = events.map { event -> Event in
                        var updatedEvent = event
                        updatedEvent.images = eventImagesDict[event.id.uuidString] ?? []
                        return updatedEvent
                    }
                    
                    print("Successfully fetched all events with their images.")
                    completion(.success(updatedEvents))
                }
                
            case .failure(let error):
                print("Failed to fetch events: \(error.localizedDescription)")
                completion(.failure(error))
            }
        }
    }
    
    func getEventsByStatus(uid: String, status: EventStatus, completion: @escaping (Result<[Event], Error>) -> Void) {
        eventMetaDataManager.getEventsByStatus(uid: uid, status: status) { result in
            switch result {
            case .success(let events):
                guard !events.isEmpty else {
                    completion(.success([])) // Return early if no events
                    return
                }
                
                let dispatchGroup = DispatchGroup()
                var eventImagesDict: [String: [String]] = [:] // Store images by eventId
                
                // Fetch images for all events concurrently
                for event in events {
                    dispatchGroup.enter()
                    self.eventImageManager.retrieveEventImages(eventId: event.id.uuidString) { images in
                        eventImagesDict[event.id.uuidString] = images
                        dispatchGroup.leave()
                    }
                }
                
                // Notify when all image fetches are complete
                dispatchGroup.notify(queue: .main) {
                    let updatedEvents = events.map { event -> Event in
                        var updatedEvent = event
                        updatedEvent.images = eventImagesDict[event.id.uuidString] ?? []
                        return updatedEvent
                    }
                    
                    print("Successfully fetched all events with their images.")
                    completion(.success(updatedEvents))
                }
                
            case .failure(let error):
                print("Failed to fetch events: \(error.localizedDescription)")
                completion(.failure(error))
            }
        }
    }
}

extension FirebaseEventService {
    func uploadGuestsAndBuildDict(
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
                    let urlString = try await self.eventImageManager.uploadSingleImage(
                        img,
                        folder: "guest_speakers",
                        id: guest.id,
                        index: idx
                    )
                    let entry: [String: String] = [
                        "id": guest.id.uuidString,
                        "name": guest.name,
                        "role": guest.role,
                        "imageUrl": urlString
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
