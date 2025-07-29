//
//  FirebaseInteractionService.swift
//  Vibesy
//
//  Created by Alexander Cleoni on 1/16/25.
//

class FirebaseInteractionService: InteractionService {
    let interactionManager: InteractionManager = InteractionManager()

    func likeEvent(uid: String, eventId: String, completion: @escaping (Error?) -> Void) {
        interactionManager.likeEvent(uid: uid, eventId: eventId) { error in
            if let error {
                completion(error)
            }
        }
    }
    
    func unlikeEvent(uid: String, eventId: String, completion: @escaping (Error?) -> Void) {
        interactionManager.unlikeEvent(uid: uid, eventId: eventId) { error in
            if let error {
                completion(error)
            } else {
                completion(nil)
            }
        }
    }
    
    func dislikeEvent(uid: String, eventId: String, completion: @escaping(Error?) -> Void) {
        interactionManager.dislikeEvent(uid: uid, eventId: eventId) { error in
            if let error {
                completion(error)
            }
        }
    }
    
    func reserveEvent(uid: String, eventId: String, completion: @escaping ((any Error)?) -> Void) {
        interactionManager.reserveEvent(uid: uid, eventId: eventId) { error in
            if let error {
                completion(error)
            }
        }
    }
    
    func cancelEventReservation(uid: String, eventId: String, completion: @escaping ((any Error)?) -> Void) {
        interactionManager.cancelEventReservation(uid: uid, eventId: eventId) { error in
            if let error {
                completion(error)
            } else {
                completion(nil)
            }
        }
    }
}
