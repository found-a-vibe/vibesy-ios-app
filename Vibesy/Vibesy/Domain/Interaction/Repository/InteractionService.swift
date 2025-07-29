//
//  InteractionService.swift
//  Vibesy
//
//  Created by Alexander Cleoni on 1/16/25.
//

protocol InteractionService {
    func likeEvent(uid: String, eventId: String, completion: @escaping (Error?) -> Void)
    func dislikeEvent(uid: String, eventId: String, completion: @escaping (Error?) -> Void)
    func unlikeEvent(uid: String, eventId: String, completion: @escaping (Error?) -> Void)
    func reserveEvent(uid: String, eventId: String, completion: @escaping (Error?) -> Void)
    func cancelEventReservation(uid: String, eventId: String, completion: @escaping (Error?) -> Void)

}
