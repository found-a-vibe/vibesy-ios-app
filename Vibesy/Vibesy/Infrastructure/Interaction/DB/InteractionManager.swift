//
//  InteractionManager.swift
//  Vibesy
//
//  Created by Alexander Cleoni on 1/16/25.
//
import FirebaseFirestore

struct InteractionManager {
    private let firestore = Firestore.firestore()
    
    func likeEvent(uid: String, eventId: String, completion: @escaping (Error?) -> Void) {
        let userRef = firestore.collection("users").document(uid)
        let eventRef = firestore.collection("events").document(eventId.lowercased())

        // 🔹 Ensure the event exists before starting the transaction
        eventRef.getDocument { (document, error) in
            guard document?.exists == true else {
                print("Event not found before transaction.")
                completion(NSError(domain: "Firestore", code: 404, userInfo: [NSLocalizedDescriptionKey: "Event does not exist"]))
                return
            }

            // 🔹 Run the transaction after confirming the event exists
            firestore.runTransaction({ (transaction, errorPointer) -> Any? in
                guard
                    let eventSnapshot = try? transaction.getDocument(eventRef),
                    let userSnapshot = try? transaction.getDocument(userRef),
                    eventSnapshot.exists
                else {
                    print("Transaction still cannot see the event.")
                    return nil
                }

                // Update user's liked events
                var likedEvents = userSnapshot.get("likedEvents") as? [String] ?? []
                if !likedEvents.contains(eventId) {
                    likedEvents.append(eventId)
                    transaction.updateData(["likedEvents": likedEvents], forDocument: userRef)
                }

                // Update event's likedBy list and interactions
                var likes = eventSnapshot.get("likes") as? [String] ?? []
                var interactions = eventSnapshot.get("interactions") as? [String] ?? []

                if !likes.contains(uid) && !interactions.contains(uid) {
                    likes.append(uid)
                    interactions.append(uid)
                    transaction.updateData(["likes": likes, "interactions": interactions], forDocument: eventRef)
                }

                print("Transaction successfully updated event.")
                return nil
            }) { (_, error) in
                completion(error)
            }
        }
    }
    
    func unlikeEvent(uid: String, eventId: String, completion: @escaping (Error?) -> Void) {
        let userRef = firestore.collection("users").document(uid)
        let eventRef = firestore.collection("events").document(eventId.lowercased())

        // Ensure the event exists before transaction
        eventRef.getDocument { (document, error) in
            guard document?.exists == true else {
                print("Event not found before transaction.")
                completion(NSError(domain: "Firestore", code: 404, userInfo: [NSLocalizedDescriptionKey: "Event does not exist"]))
                return
            }

            // Run transaction to remove like
            firestore.runTransaction({ (transaction, errorPointer) -> Any? in
                guard
                    let userSnapshot = try? transaction.getDocument(userRef),
                    let eventSnapshot = try? transaction.getDocument(eventRef)
                else {
                    print("Failed to retrieve user or event document.")
                    return nil
                }

                // Remove event from user's liked list
                var likedEvents = userSnapshot.get("likedEvents") as? [String] ?? []
                if likedEvents.contains(eventId) {
                    likedEvents.removeAll { $0 == eventId }
                    transaction.updateData(["likedEvents": likedEvents], forDocument: userRef)
                }

                // Remove user from event's likes & interactions
                var likes = eventSnapshot.get("likes") as? [String] ?? []
                var interactions = eventSnapshot.get("interactions") as? [String] ?? []

                if likes.contains(uid) || interactions.contains(uid) {
                    likes.removeAll { $0 == uid }
                    interactions.removeAll { $0 == uid }
                    transaction.updateData(["likes": likes, "interactions": interactions], forDocument: eventRef)
                }

                print("Successfully unliked event.")
                return nil
            }) { (_, error) in
                completion(error)
            }
        }
    }
    
    func dislikeEvent(uid: String, eventId: String, completion: @escaping (Error?) -> Void) {
        let userRef = firestore.collection("users").document(uid)
        let eventRef = firestore.collection("events").document(eventId.lowercased())

        // 🔹 Ensure the event exists before modifying
        eventRef.getDocument { (document, error) in
            guard document?.exists == true else {
                print("Event not found before transaction.")
                completion(NSError(domain: "Firestore", code: 404, userInfo: [NSLocalizedDescriptionKey: "Event does not exist"]))
                return
            }

            // 🔹 Run transaction to add dislike
            firestore.runTransaction({ (transaction, errorPointer) -> Any? in
                guard
                    let userSnapshot = try? transaction.getDocument(userRef),
                    let eventSnapshot = try? transaction.getDocument(eventRef)
                else {
                    print("Failed to retrieve user or event document.")
                    return nil
                }

                // Add event to user's disliked list
                var dislikedEvents = userSnapshot.get("dislikedEvents") as? [String] ?? []
                if !dislikedEvents.contains(eventId) {
                    dislikedEvents.append(eventId)
                    transaction.updateData(["dislikedEvents": dislikedEvents], forDocument: userRef)
                }

                // Update event's dislikes and interactions
                var dislikes = eventSnapshot.get("dislikes") as? [String] ?? []
                var interactions = eventSnapshot.get("interactions") as? [String] ?? []

                if !dislikes.contains(uid) || !interactions.contains(uid) {
                    dislikes.append(uid)
                    interactions.append(uid)
                    transaction.updateData(["dislikes": dislikes, "interactions": interactions], forDocument: eventRef)
                }

                print("Successfully disliked event.")
                return nil
            }) { (_, error) in
                completion(error)
            }
        }
    }
    
    func reserveEvent(uid: String, eventId: String, completion: @escaping (Error?) -> Void) {
        let userRef = firestore.collection("users").document(uid)
        let eventRef = firestore.collection("events").document(eventId.lowercased())

        // 🔹 Ensure the event exists before modifying
        eventRef.getDocument { (document, error) in
            guard document?.exists == true else {
                print("Event not found before transaction.")
                completion(NSError(domain: "Firestore", code: 404, userInfo: [NSLocalizedDescriptionKey: "Event does not exist"]))
                return
            }

            // 🔹 Run transaction to add reservation
            firestore.runTransaction({ (transaction, errorPointer) -> Any? in
                guard
                    let userSnapshot = try? transaction.getDocument(userRef),
                    let eventSnapshot = try? transaction.getDocument(eventRef)
                else {
                    print("Failed to retrieve user or event document.")
                    return nil
                }

                // Add event to user's reservation list
                var reservedEvents = userSnapshot.get("reservedEvents") as? [String] ?? []
                if !reservedEvents.contains(eventId) {
                    reservedEvents.append(eventId)
                    transaction.updateData(["reservedEvents": reservedEvents], forDocument: userRef)
                }

                // Update event's reservations
                var reservations = eventSnapshot.get("reservations") as? [String] ?? []

                if !reservations.contains(uid) {
                    reservations.append(uid)
                    transaction.updateData(["reservations": reservations ], forDocument: eventRef)
                }

                print("Successfully reserved event.")
                return nil
            }) { (_, error) in
                completion(error)
            }
        }
    }
    
    func cancelEventReservation(uid: String, eventId: String, completion: @escaping (Error?) -> Void) {
        let userRef = firestore.collection("users").document(uid)
        let eventRef = firestore.collection("events").document(eventId.lowercased())

        // Ensure the event exists before transaction
        eventRef.getDocument { (document, error) in
            guard document?.exists == true else {
                print("Event not found before transaction.")
                completion(NSError(domain: "Firestore", code: 404, userInfo: [NSLocalizedDescriptionKey: "Event does not exist"]))
                return
            }

            // Run transaction to remove like
            firestore.runTransaction({ (transaction, errorPointer) -> Any? in
                guard
                    let userSnapshot = try? transaction.getDocument(userRef),
                    let eventSnapshot = try? transaction.getDocument(eventRef)
                else {
                    print("Failed to retrieve user or event document.")
                    return nil
                }

                // Remove event from user's liked list
                var reservedEvents = userSnapshot.get("reservedEvents") as? [String] ?? []
                if reservedEvents.contains(eventId) {
                    reservedEvents.removeAll { $0 == eventId }
                    transaction.updateData(["reservedEvents": reservedEvents], forDocument: userRef)
                }

                // Remove user from event's likes & interactions
                var reservations = eventSnapshot.get("reservations") as? [String] ?? []

                if reservations.contains(uid) {
                    reservations.removeAll { $0 == uid }
                    transaction.updateData(["reservations": reservations], forDocument: eventRef)
                }

                print("Successfully cancelled event reservation.")
                return nil
            }) { (_, error) in
                completion(error)
            }
        }
    }
}
