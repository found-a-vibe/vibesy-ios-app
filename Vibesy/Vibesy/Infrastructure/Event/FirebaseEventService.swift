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
    func createOrUpdateEvent(_ event: Event, guestImages: [UUID: UIImage]) async throws -> Event {
        // Base payload (immutable) - guests will be properly handled in uploadGuestsAndBuildDict
        var base: [String: Any] = [
            "id": event.id.uuidString,
            "title": event.title,
            "description": event.description,
            "date": event.date,
            "timeRange": event.timeRange,
            "location": event.location,
            "hashtags": Array(event.hashtags),
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
        async let guestsDict: [String: Any] = Self.uploadGuestsAndBuildDict(
            for: event,
            guestImages: guestImages
        )

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

        // Return updated model with image URLs and guest image URLs
        var updatedEvent = event
        updatedEvent.setImageURLs(imageURLs)
        
        // Update guest objects with their uploaded image URLs
        if let guestsArray = guests["guests"] as? [[String: Any]] {
            // Clear existing guests and add updated ones
            var guestsToAdd: [Guest] = []
            for guestDict in guestsArray {
                if let guestId = UUID(uuidString: guestDict["id"] as? String ?? ""),
                   let name = guestDict["name"] as? String,
                   let role = guestDict["role"] as? String,
                   let imageUrl = guestDict["imageUrl"] as? String {
                    
                    do {
                        let updatedGuest = try Guest(id: guestId, name: name, role: role, imageUrl: imageUrl.isEmpty ? nil : imageUrl)
                        guestsToAdd.append(updatedGuest)
                        print("✅ Updated guest \(name) with imageUrl: \(imageUrl.isEmpty ? "[EMPTY]" : imageUrl)")
                    } catch {
                        print("❌ Failed to create updated guest \(name): \(error.localizedDescription)")
                    }
                }
            }
            
            // Replace guests with updated versions
            updatedEvent = try Event(
                id: updatedEvent.id,
                title: updatedEvent.title,
                description: updatedEvent.description,
                date: updatedEvent.date,
                timeRange: updatedEvent.timeRange,
                location: updatedEvent.location,
                createdBy: updatedEvent.createdBy
            )
            
            // Set image URLs
            updatedEvent.setImageURLs(imageURLs)
            
            // Add updated guests
            for guest in guestsToAdd {
                try? updatedEvent.addGuest(guest)
            }
            
            // Add price details
            for priceDetail in event.priceDetails {
                updatedEvent.addPriceDetail(priceDetail)
            }
            
            // Set hashtags
            updatedEvent.hashtags = event.hashtags
            
            // Set interactions
            for userID in event.likes {
                updatedEvent.addLike(from: userID)
            }
            for userID in event.reservations {
                updatedEvent.addReservation(from: userID)
            }
            for userID in event.interactions {
                updatedEvent.addInteraction(from: userID)
            }
            
            // Set Stripe info if available
            if let stripeProductId = event.stripeProductId,
               let stripeConnectedAccountId = event.stripeConnectedAccountId {
                updatedEvent.setStripeProductInfo(
                    productId: stripeProductId,
                    connectedAccountId: stripeConnectedAccountId
                )
            }
        }
        
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

// MARK: - Sendable guest data structure for concurrency
struct GuestUploadResult: Sendable {
    let id: String
    let name: String
    let role: String
    let imageUrl: String
}

extension FirebaseEventService {
    private static func uploadGuestsAndBuildDict(
        for event: Event,
        guestImages: [UUID: UIImage]
    ) async throws -> [String: Any] {
        let guests = event.guests
        guard !guests.isEmpty else { return [:] }
        
        print("🔄 uploadGuestsAndBuildDict called with:")
        print("  - Event guests count: \(guests.count)")
        print("  - GuestImages dictionary count: \(guestImages.count)")
        print("  - GuestImages keys: \(Array(guestImages.keys))")
        print("  - Event guest IDs: \(guests.map { $0.id })")
        
        // Upload guest images and build results concurrently
        let guestResults = try await withThrowingTaskGroup(of: GuestUploadResult.self) { group in
            for guest in guests {
                group.addTask {
                    var imageUrl = guest.imageUrl ?? ""
                    
                    // Upload guest image if available
                    if let image = guestImages[guest.id] {
                        print("🔄 Uploading image for guest: \(guest.name) (ID: \(guest.id))")
                        do {
                            imageUrl = try await FirebaseEventImageManager.uploadGuestImage(
                                image: image,
                                eventId: event.id,
                                guestId: guest.id
                            )
                            print("✅ Guest image uploaded successfully: \(imageUrl)")
                        } catch {
                            print("❌ Failed to upload guest image for \(guest.name): \(error.localizedDescription)")
                            print("❌ Full error: \(error)")
                            // Keep original imageUrl or empty string
                        }
                    } else {
                        print("⚠️ No image found for guest \(guest.name) in guestImages dictionary")
                        print("⚠️ Available guest IDs in dictionary: \(Array(guestImages.keys))")
                        print("⚠️ Current guest ID: \(guest.id)")
                        print("⚠️ Guest's existing imageUrl: \(guest.imageUrl ?? "[nil]")")
                    }
                    
                    return GuestUploadResult(
                        id: guest.id.uuidString,
                        name: guest.name,
                        role: guest.role,
                        imageUrl: imageUrl
                    )
                }
            }
            
            var results: [GuestUploadResult] = []
            for try await result in group {
                results.append(result)
            }
            return results
        }
        
        // Convert results to dictionary format
        let guestsDictArray = guestResults.map { result in
            [
                "id": result.id,
                "name": result.name,
                "role": result.role,
                "imageUrl": result.imageUrl
            ] as [String: Any]
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
