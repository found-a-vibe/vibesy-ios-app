//
//  FirebaseEventMetaDataManager.swift
//  Vibesy
//
//  Created by Alexander Cleoni on 12/19/24.
//
import FirebaseFirestore

struct FirebaseEventMetaDataManager {
    private let firestore = Firestore.firestore()
    private let eventParser = EventParser()
    
    // Submit Event Object to Firestore
    func createOrUpdateEvent(eventId: String, createdByUid: String, eventDict: [String: Any], completion: @escaping (Result<Void, Error>) -> Void) {
        let eventRef = firestore.collection("events").document(eventId.lowercased())
        
        // Only get user ref if this is a user-generated event
        let isUserGenerated = !createdByUid.isEmpty
        let userRef = isUserGenerated ? firestore.collection("users").document(createdByUid) : nil

        firestore.runTransaction({ transaction, errorPointer -> Any? in
            // Retrieve event document
            let eventSnapshot = try? transaction.getDocument(eventRef)
            let userSnapshot = isUserGenerated ? (try? transaction.getDocument(userRef!)) : nil
            
            // If event exists, update it; otherwise, create it
            if eventSnapshot?.exists == true {
                print("Updating existing event: \(eventId)")
                transaction.updateData(eventDict, forDocument: eventRef)
            } else {
                print("Creating new event: \(eventId)")
                transaction.setData(eventDict, forDocument: eventRef)
            }

            // Update user's posted events list only for user-generated events
            if isUserGenerated, let userSnapshot = userSnapshot, let userRef = userRef {
                var postedEvents = Set(userSnapshot.get("postedEvents") as? [String] ?? [])
                if postedEvents.insert(eventId).inserted { // Efficiently ensures uniqueness
                    transaction.updateData(["postedEvents": Array(postedEvents)], forDocument: userRef)
                }
            }
            
            print("Transaction completed successfully.")
            return nil
        }) { _, error in
            if let error = error {
                print("Error saving event: \(error.localizedDescription)")
                completion(.failure(error))
            } else {
                completion(.success(()))
            }
        }
    }
    
    func deleteEvent(eventId: String, createdByUid: String, completion: @escaping (Result<Void, Error>) -> Void) {
        let eventRef = firestore.collection("events").document(eventId.lowercased())
        
        // Only get user ref if this is a user-generated event
        let isUserGenerated = !createdByUid.isEmpty
        let userRef = isUserGenerated ? firestore.collection("users").document(createdByUid) : nil

        firestore.runTransaction({ transaction, errorPointer -> Any? in
            do {
                // Retrieve event document
                let eventSnapshot = try transaction.getDocument(eventRef)
                let userSnapshot = isUserGenerated ? (try transaction.getDocument(userRef!)) : nil

                // Ensure event exists before deleting
                if eventSnapshot.exists {
                    print("Deleting event: \(eventId)")
                    transaction.deleteDocument(eventRef)
                } else {
                    print("Event \(eventId) does not exist. Skipping deletion.")
                }

                // Update user's postedEvents list only for user-generated events
                if isUserGenerated, let userSnapshot = userSnapshot, userSnapshot.exists, let userRef = userRef {
                    print("Removing event \(eventId) from user's postedEvents list.")
                    transaction.updateData(["postedEvents": FieldValue.arrayRemove([eventId])], forDocument: userRef)
                } else if isUserGenerated {
                    print("User document not found. Skipping postedEvents update.")
                }

                print("Transaction completed successfully.")
                return nil

            } catch {
                print("Transaction failed: \(error.localizedDescription)")
                errorPointer?.pointee = error as NSError
                return nil
            }
        }) { _, error in
            if let error = error {
                print("Error deleting event: \(error.localizedDescription)")
                completion(.failure(error))
            } else {
                print("Event deletion successful.")
                completion(.success(()))
            }
        }
    }
    
    func getAllEvents(uid: String, completion: @escaping (Result<[Event], Error>) -> Void) {
        firestore.collection("events")
            .getDocuments { snapshot, error in
            if let error = error {
                print("Error fetching events: \(error.localizedDescription)")
                completion(.failure(error))
                return
            }
            
            guard let documents = snapshot?.documents else {
                print("No events found.")
                completion(.success([])) // Return an empty array instead of a failure
                return
            }
            
            // Process all events using compactMap to remove nil values
            let events = documents.compactMap { document -> Event? in
                let data = document.data()
                let interactions = data["interactions"] as? [String] ?? []
                let reservations = data["reservations"] as? [String] ?? []
                
                // Skip events where the user has interacted or reserved
                guard !interactions.contains(uid) else { return nil }
                guard !reservations.contains(uid) else {return nil}
                
                // Parse event data
                return eventParser.parse(from: data)
            }
            
            print("Retrieved \(events.count) events.")
            completion(.success(events))
        }
    }
    
    // MARK: - Get Events By (liked, posted, reserved or attended)
    func getEventsByStatus(uid: String, status: EventStatus, completion: @escaping (Result<[Event], Error>) -> Void) {
        let userRef = firestore.collection("users").document(uid)
        
        userRef.getDocument { (document, error) in
            if let error = error {
                print("Error fetching liked events: \(error)")
                completion(.failure(error))
                return
            }
            
            guard let document = document, let data = document.data() else {
                completion(.success([]))
                return
            }
            
            let eventIds = data[status.rawValue] as? [String] ?? []
            self.getEventsByIds(eventIds: eventIds, completion: completion)
        }
    }
    
    // MARK: - Get Events By Ids
    private func getEventsByIds(eventIds: [String], completion: @escaping (Result<[Event], Error>) -> Void) {
        guard !eventIds.isEmpty else {
            completion(.success([])) // Return immediately if no event IDs
            return
        }

        firestore.collection("events")
            .whereField(FieldPath.documentID(), in: eventIds.map { $0.lowercased() })
            .getDocuments { snapshot, error in
                if let error = error {
                    print("Error fetching events: \(error.localizedDescription)")
                    completion(.failure(error))
                    return
                }

                guard let documents = snapshot?.documents else {
                    print("No events found for provided IDs.")
                    completion(.success([]))
                    return
                }

                // Parse all events in a single step using `compactMap`
                let events = documents.compactMap { document -> Event? in
                    let data = document.data()
                    if let event = eventParser.parse(from: data) {
                        return event
                    } else {
                        print("Failed to parse event: \(document.documentID)")
                        return nil
                    }
                }

                print("Retrieved \(events.count) events.")
                completion(.success(events))
            }
    }
}

extension FirebaseEventMetaDataManager {
    func createOrUpdateEventAsync(eventId: String,
                                  createdByUid: String,
                                  eventDict: [String: Any]) async throws {
        try await withCheckedThrowingContinuation { cont in
            createOrUpdateEvent(eventId: eventId, createdByUid: createdByUid, eventDict: eventDict) { result in
                switch result {
                case .success:       cont.resume()
                case .failure(let e): cont.resume(throwing: e)
                }
            }
        }
    }
}
