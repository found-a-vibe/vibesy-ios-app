//
//  InteractionModel.swift
//  Vibesy
//
//  Created by Alexander Cleoni on 1/16/25.
//
import SwiftUI

enum InteractWithEventStatus {
    case idle
    case interacting
    case completed
}

@MainActor
class InteractionModel: ObservableObject {
    let service: InteractionService
    @Published var interactWithEventStatus: InteractWithEventStatus = .idle {
        didSet {
            print("⚡️ Status changed to: \(interactWithEventStatus)")
        }
    }
    
    init(service: InteractionService) {
        self.service = service
    }
    
    func likeEvent(userId: String, eventId: String) {
        service.likeEvent(uid: userId, eventId: eventId) { error in
            if let error = error {
                print("Error liking event: \(error)")
            } else {
                print("Event liked successfully.")
            }
        }
    }
    
    func unlikeEvent(userId: String, eventId: String, completion: (() -> Void)? = nil) {
        service.unlikeEvent(uid: userId, eventId: eventId) { error in
            if let error = error {
                print("Error unliking event: \(error)")
            } else {
                if let completion {
                    completion()
                }
                print("Event unliked successfully.")
            }
        }
    }
    
    func dislikeEvent(userId: String, eventId: String) {
        service.dislikeEvent(uid: userId, eventId: eventId) { error in
            if let error = error {
                print("Error disliking event: \(error)")
            } else {
                print("Event disliked successfully.")
            }
        }
    }
}
