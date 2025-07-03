//
//  FriendshipModel.swift
//  Vibesy
//
//  Created by Alexander Cleoni on 1/24/25.
//

import SwiftUI

class FriendshipModel: ObservableObject {
    private let service: FriendshipService
    @Published var friendRequests: [FriendRequest?]
    @Published var friendList: [String?] = []
    
    init(service: FriendshipService, friendRequests: [FriendRequest]) {
        self.service = service
        self.friendRequests = []
    }
    
    // Send a Friend Request
    func sendFriendRequest(fromUserId: String, fromUserProfile: UserProfile, toUserId: String, message: String?) {
        service.sendFriendRequest(fromUserId: fromUserId, fromUserProfile: fromUserProfile, toUserId: toUserId, message: message) { error in
            if let error = error {
                print("Error sending Friend Request: \(error)")
            } else {
                print("Friend Request sent successfully.")
            }
        }
    }
    
    // Send a Friend Request
    func deleteFriendRequest(fromUserId: String, toUserId: String) {
        service.deleteFriendRequest(fromUserId: fromUserId, toUserId: toUserId) { error in
            if let error = error {
                print("Error sending Friend Request: \(error)")
            } else {
                DispatchQueue.main.async {
                    self.friendRequests.removeAll { $0?.fromUserId == fromUserId }
                }
                print("Friend Request sent successfully.")
            }
        }
    }
    
    // Send a Friend Request
    func acceptFriendRequest(fromUserId: String, toUserId: String) {
        service.acceptFriendRequest(fromUserId: fromUserId, toUserId: toUserId) { error in
            if let error = error {
                print("Error sending Friend Request: \(error)")
            } else {
                DispatchQueue.main.async {
                    self.friendRequests.removeAll { $0?.fromUserId == fromUserId }
                }
                print("Friend Request sent successfully.")
            }
        }
    }
    
    func fetchPendingFriendRequests(userId: String, status: String) {
        service.fetchPendingFriendRequests(userId: userId, status: status) { (requests, error) in
            if let error = error {
                print("Error fetching friend requests: \(error.localizedDescription)")
            } else if let requests = requests {
                self.friendRequests = requests
            }
        }
    }
    
    func fetchFriendList(userId: String) {
        service.fetchFriendList(userId: userId) { (friendsIds, error) in
            if let error = error {
                print("Error fetching friend requests: \(error.localizedDescription)")
            } else if let friendsIds = friendsIds {
                self.friendList = friendsIds
            }
        }
    }
}
