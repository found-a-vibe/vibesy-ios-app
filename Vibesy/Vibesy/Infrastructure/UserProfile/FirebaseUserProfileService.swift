//
//  FirebaseUserProfileService.swift
//  Vibesy
//
//  Created by Alexander Cleoni on 12/15/24.
//

import SwiftUI
import FirebaseStorage
import FirebaseFirestore

struct FirebaseUserProfileService: UserProfileService {
    let profileImageManager = FirebaseProfileImageManager()
    let profileMetaDataManager = UserProfileMetaDataManager()
    
    func getUserProfile(userId: String, completion: @escaping (Result<(UserProfile), Error>) -> Void) {
        profileMetaDataManager.getUserProfileMetadata(userId: userId) { metadataResult in
            switch metadataResult {
            case .success(let metadata):
                // Parse metadata into a UserProfile object
                guard
                    let age = metadata["age"] as? String,
                    let bio = metadata["bio"] as? String,
                    let fullName = metadata["fullName"] as? String,
                    let interests = metadata["interests"] as? [String],
                    let pronouns = metadata["pronouns"] as? String,
                    let profileImageUrl = metadata["profileImageUrl"] as? String
                else {
                    completion(.failure(NSError(domain: "UserProfileParsing", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to parse user profile metadata"])))
                    return
                }
                
                let userProfile = UserProfile(
                    age: age,
                    bio: bio,
                    fullName: fullName,
                    interests: interests,
                    pronouns: pronouns,
                    profileImageUrl: profileImageUrl
                )
                completion(.success((userProfile)))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    func updateUserProfile(userId: String, image: UIImage?, userProfile: UserProfile, completion: @escaping (Result<String?, Error>) -> Void) {
        if let image {
            profileImageManager.upload(uid: userId, image: image) { result in
                switch result {
                case .success(let imageUrl):
                    let metadata: [String: Any] = [
                        "age": userProfile.age,
                        "bio": userProfile.bio,
                        "fullName": userProfile.fullName,
                        "interests": userProfile.interests,
                        "pronouns": userProfile.pronouns,
                        "profileImageUrl": imageUrl
                    ]
                    self.profileMetaDataManager.updateUserProfileMetadata(userId: userId, metadata: metadata) { result in
                        switch result {
                        case .success:
                            completion(.success((imageUrl)))
                        case .failure(let error):
                            completion(.failure(error))
                        }
                    }
                case .failure(let error):
                    completion(.failure(error))
                }
            }
        } else {
            let rawMetadata: [String: Any?] = [
                "age": userProfile.age,
                "bio": userProfile.bio,
                "fullName": userProfile.fullName,
                "interests": userProfile.interests,
                "pronouns": userProfile.pronouns,
            ]
            let metadata = rawMetadata.compactMapValues { $0 }
            self.profileMetaDataManager.updateUserProfileMetadata(userId: userId, metadata: metadata) { result in
                switch result {
                case .success:
                    completion(.success((nil)))
                case .failure(let error):
                    completion(.failure(error))
                }
            }
        }
    }
}

extension FirebaseUserProfileService {
    func getMatchedUserProfiles(userId: String, userIds: Set<String>, completion: @escaping (Result<[(UserProfile, UIImage?)], Error>) -> Void) {
        profileMetaDataManager.getMatchedUsers(userId: userId, userIds: userIds) { matchedUsersResult in
            switch matchedUsersResult {
            case .success(let matchedUsersMetadata):
                var userProfiles: [(UserProfile, UIImage?)] = []
                let dispatchGroup = DispatchGroup()
                var fetchError: Error?
                
                for metadata in matchedUsersMetadata {
                    dispatchGroup.enter()
                    
                    do {
                        let userProfile = try self.parseUserProfile(from: metadata)
                        userProfiles.append((userProfile, nil))
                    } catch let error {
                        fetchError = error
                    }
                    
                    dispatchGroup.leave()
                }
                
                dispatchGroup.notify(queue: .main) {
                    if let error = fetchError {
                        completion(.failure(error))
                    } else {
                        completion(.success(userProfiles))
                    }
                }
                
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    private func parseUserProfile(from metadata: [String: Any]) throws -> UserProfile {
        guard
            let uid = metadata["uid"] as? String,
            let age = metadata["age"] as? String,
            let bio = metadata["bio"] as? String,
            let fullName = metadata["fullName"] as? String,
            let interests = metadata["interests"] as? [String],
            let pronouns = metadata["pronouns"] as? String,
            let profileImageUrl = metadata["profileImageUrl"] as? String,
            let friendRequests = metadata["friendRequests"] as? [String: Any]?,
            let friends = metadata["friends"] as? [String: Any]?
        else {
            throw NSError(domain: "UserProfileParsing", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to parse user profile metadata"])
        }
        
        // For now, use empty dictionaries as we need proper parsing logic for these complex types
        // TODO: Implement proper parsing for FriendRequest and Friend objects from Firebase data
        return UserProfile(
            uid: uid,
            age: age,
            bio: bio,
            fullName: fullName,
            interests: interests,
            pronouns: pronouns,
            profileImageUrl: profileImageUrl,
            friendRequests: [:],  // Empty until proper parsing is implemented
            friends: [:]          // Empty until proper parsing is implemented
        )
    }
}

extension FirebaseUserProfileService {
    func addLikedEventToUserProfile(for userId: String, withLikedEventId eventId: String, completion: @escaping (Result<Void, Error>) -> Void) {
        profileMetaDataManager.addLikedEvent(userId: userId, eventId: eventId) { result in
            
        }
    }
}
