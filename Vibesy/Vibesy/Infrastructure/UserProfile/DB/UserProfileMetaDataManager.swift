//
//  UserProfileMetaDataManager.swift
//  Vibesy
//
//  Created by Alexander Cleoni on 12/15/24.
//
import FirebaseFirestore

class UserProfileMetaDataManager {
    private let firestore = Firestore.firestore()
    
    func getMatchedUsers(
        userId: String,
        userIds: Set<String>,
        completion: @escaping (Result<[[String: Any]], Error>) -> Void
    ) {
        let firestore = Firestore.firestore()
        var matchedUsers: [[String: Any]] = []
        let dispatchGroup = DispatchGroup()
        
        for toUserId in userIds {
            dispatchGroup.enter() // Enter for each userId
            
            let userProfileRef = firestore
                .collection("users")
                .document(toUserId)
                .collection("profile")
                .document("metadata")
            
            let friendRequestRef = firestore
                .collection("users")
                .document(toUserId)
                .collection("friendRequests")
                .document(userId) // Check if this user sent a request
            
            var userData: [String: Any] = ["uid": toUserId] // Initialize with userId
            
            // Fetch User Profile Metadata
            userProfileRef.getDocument { document, error in
                if let error = error {
                    print("Error fetching metadata for \(toUserId): \(error.localizedDescription)")
                } else if let document = document, document.exists, let data = document.data() {
                    userData.merge(data) { (_, new) in new }
                }
                
                // Fetch Friend Request Data
                friendRequestRef.getDocument { requestDoc, requestError in
                    if let requestError = requestError {
                        print("Error fetching friend request for \(toUserId): \(requestError.localizedDescription)")
                    } else if let requestDoc = requestDoc, requestDoc.exists, let requestData = requestDoc.data() {
                        userData["friendRequests"] = requestData
                    } else {
                        userData["friendRequests"] = nil // No request found
                    }
                    
                    matchedUsers.append(userData) // Append final merged data
                    dispatchGroup.leave() // Leave after both calls finish
                }
            }
        }
        
        // Notify when all async calls are done
        dispatchGroup.notify(queue: .main) {
            if !matchedUsers.isEmpty {
                completion(.success(matchedUsers))
            } else {
                completion(.failure(NSError(domain: "MatchedUsersError", code: -1, userInfo: [NSLocalizedDescriptionKey: "No users matched"])))
            }
        }
    }
    
    func getUserProfileMetadata(userId: String, completion: @escaping (Result<[String: Any], Error>) -> Void) {
        firestore
            .collection("users")
            .document(userId)
            .collection("profile")
            .document("metadata")
            .getDocument { document, error in
                if let error = error {
                    completion(.failure(error)) // Handle Firestore retrieval error
                } else if let document = document, document.exists, let data = document.data() {
                    completion(.success(data)) // Successfully retrieved metadata
                } else {
                    completion(.failure(NSError(domain: "MetadataError", code: -1, userInfo: [NSLocalizedDescriptionKey: "No metadata found"])))
                }
            }
    }
    
    func updateUserProfileMetadata(userId: String, metadata: [String: Any], completion: @escaping (Result<Void, Error>) -> Void) {
        let userRef = firestore.collection("users").document(userId) // Reference to user document
        let metadataRef = userRef.collection("profile").document("metadata") // Reference to profile metadata document
        
        firestore.runTransaction { (transaction, errorPointer) -> Any? in
            let userSnapshot: DocumentSnapshot
            do {
                userSnapshot = try transaction.getDocument(userRef)
            } catch let error {
                errorPointer?.pointee = error as NSError
                return nil
            }
            
            var userDataToUpdate: [String: Any] = [:]
            
            if userSnapshot.exists, userSnapshot.data()?["createdAt"] == nil {
                userDataToUpdate["createdAt"] = FieldValue.serverTimestamp()
            } else if !userSnapshot.exists {
                userDataToUpdate["createdAt"] = FieldValue.serverTimestamp() // Set on first-time creation
            }
            
            if !userDataToUpdate.isEmpty {
                transaction.setData(userDataToUpdate, forDocument: userRef, merge: true)
            }
            
            transaction.setData(metadata, forDocument: metadataRef, merge: true)
            
            return nil
        } completion: { (result, error) in
            if let error = error {
                completion(.failure(error))
            } else {
                completion(.success(()))
            }
        }
    }
    
    func addLikedEvent(userId: String, eventId: String, completion: @escaping (Result<Void, Error>) -> Void) {
        firestore
            .collection("users")
            .document(userId)
            .collection("profile")
            .document("metadata")
            .updateData(["likedEvents": FieldValue.arrayUnion([eventId])]) { error in
                if let error = error {
                    completion(.failure(error))
                } else {
                    completion(.success(()))
                }
            }
    }
}
