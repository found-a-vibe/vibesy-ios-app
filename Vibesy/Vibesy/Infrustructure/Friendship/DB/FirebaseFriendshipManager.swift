//
//  FirebaseFriendshipManager.swift
//  Vibesy
//
//  Created by Alexander Cleoni on 1/24/25.
//

import FirebaseFirestore

struct FriendRequest: Hashable {
    let fromUserId: String
    let fromUserName: String
    let fromUserProfilePictureUrl: String
    let timestamp: Date
}

struct FirebaseFriendshipManager {
    func sendFriendRequest(fromUserId: String, fromUserProfile: UserProfile, toUserId: String, message: String?, completion: @escaping (Error?) -> Void) {
        let db = Firestore.firestore()
        let requestRef = db.collection("users").document(toUserId).collection("friendRequests").document(fromUserId)
        
        let friendRequestData: [String: Any] = [
            "fromUserId": fromUserId,
            "fromUserName": fromUserProfile.fullName,
            "fromUserProfilePictureUrl": fromUserProfile.profileImageUrl,
            "toUserId": toUserId,
            "status": "pending",
            "message": message ?? "",
            "timestamp": Timestamp(date: Date())
        ]
        
        // Save the friend request to Firestore
        requestRef.setData(friendRequestData) { error in
            if let error = error {
                completion(error)
            } else {
                completion(nil)
            }
        }
    }
    
    func acceptFriendRequest(fromUserId: String, toUserId: String, completion: @escaping (Error?) -> Void) {
        let db = Firestore.firestore()
        let requestRef = db.collection("users").document(toUserId).collection("friendRequests").document(fromUserId)
        
        // First, delete the friend request as it's no longer needed
        requestRef.delete { error in
            if let error = error {
                completion(error) // Exit early if deletion fails
                return
            }
            
            let fromUserFriendsRef = db.collection("users").document(fromUserId).collection("friends").document(toUserId)
            let toUserFriendsRef = db.collection("users").document(toUserId).collection("friends").document(fromUserId)
            
            let batch = db.batch()
            
            // Add each user to the other's friends collection
            batch.setData(["addedAt": FieldValue.serverTimestamp()], forDocument: fromUserFriendsRef)
            batch.setData(["addedAt": FieldValue.serverTimestamp()], forDocument: toUserFriendsRef)
            
            // Commit the batch write
            batch.commit { batchError in
                completion(batchError) // Return any error or nil if successful
            }
        }
    }
    
    func deleteFriendRequest(fromUserId: String, toUserId: String, completion: @escaping (Error?) -> Void) {
        let db = Firestore.firestore()
        let requestRef = db.collection("users").document(toUserId).collection("friendRequests").document(fromUserId)
        
        // Save the friend request to Firestore
        requestRef.delete() { error in
            if let error = error {
                completion(error)
            } else {
                completion(nil)
            }
        }
    }
    
    func fetchFriendList(userId: String, completion: @escaping ([String]?, Error?) -> Void) {
        let db = Firestore.firestore()
        let requestsRef = db.collection("users").document(userId).collection("friends")
        
        requestsRef
            .getDocuments { (snapshot, error) in
                if let error = error {
                    completion(nil, error)
                    return
                }
                
                var friends: [String] = []
                
                for document in snapshot?.documents ?? [] {
                    let id = document.documentID
                    friends.append(id)
                }
                
                completion(friends, nil)
            }
    }
    
    func fetchPendingFriendRequests(userId: String, status: String, completion: @escaping ([FriendRequest]?, Error?) -> Void) {
        let db = Firestore.firestore()
        let requestsRef = db.collection("users").document(userId).collection("friendRequests")
        
        requestsRef
            .whereField("status", isEqualTo: status)  // Only fetch pending requests
            .order(by: "timestamp", descending: true)   // Order by most recent
            .getDocuments { (snapshot, error) in
                if let error = error {
                    completion(nil, error)
                    return
                }
                
                var friendRequests: [FriendRequest] = []
                
                for document in snapshot?.documents ?? [] {
                    let data = document.data()
                    if let fromUserId = data["fromUserId"] as? String,
                       let fromUserName = data["fromUserName"] as? String,
                       let fromUserProfilePictureUrl = data["fromUserProfilePictureUrl"] as? String,
                       let timestamp = (data["timestamp"] as? Timestamp)?.dateValue() {
                        
                        let friendRequest = FriendRequest(
                            fromUserId: fromUserId,
                            fromUserName: fromUserName,
                            fromUserProfilePictureUrl: fromUserProfilePictureUrl,
                            timestamp: timestamp
                        )
                        friendRequests.append(friendRequest)
                    }
                }
                
                completion(friendRequests, nil)
            }
    }
}


