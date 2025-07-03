//
//  MockUserProfileService.swift
//  Vibesy
//
//  Created by Alexander Cleoni on 12/19/24.
//

import Foundation
import SwiftUI

class MockUserProfileService: UserProfileService {
    
    var mockUserProfile: UserProfile = UserProfile(
        age: "32",
        bio: "Mock bio for testing.",
        fullName: "Mock User",
        interests: ["#mock", "#test", "#example"],
        pronouns: "They/Them"
    )
    
    var mockImage: UIImage? = nil
    
    // Simulated delay to mimic async behavior
    private let simulatedDelay: TimeInterval = 0.5
    
    func updateUserProfile(userId: String, image: UIImage?, userProfile: UserProfile, completion: @escaping (Result<String?, Error>) -> Void) {
        // Simulate a network delay
        DispatchQueue.global().asyncAfter(deadline: .now() + simulatedDelay) {
            // Mock behavior: Update the local properties to match the incoming parameters
            self.mockUserProfile = userProfile
            self.mockImage = image
            completion(.success((""))) // Simulate successful update
        }
    }
    
    func getUserProfile(userId: String, completion: @escaping (Result<(UserProfile), Error>) -> Void) {
        // Simulate a network delay
        DispatchQueue.global().asyncAfter(deadline: .now() + simulatedDelay) {
            // Return the mock data
            completion(.success((self.mockUserProfile)))
        }
    }
    
    func getMatchedUserProfiles(userId: String, userIds: Set<String>, completion: @escaping (Result<[(UserProfile, UIImage?)], Error>) -> Void) {
        // Simulate a network delay
        DispatchQueue.global().asyncAfter(deadline: .now() + simulatedDelay) {
            // Create mock profiles for each user ID
            let mockProfiles = userIds.map { userId in
                let mockProfile = UserProfile(
                    age: "25",
                    bio: "Mock bio for \(userId).",
                    fullName: "Mock User \(userId)",
                    interests: ["#mock", "#user", userId],
                    pronouns: "They/Them",
                    profileImageUrl: "https://example.com/\(userId).jpg",
                    friendRequests: [:]
                )
                return (mockProfile, self.mockImage) // Return the profile with the optional mock image
            }
            
            // Simulate a successful result
            completion(.success(mockProfiles))
        }
    }
    
    func addLikedEventToUserProfile(for userId: String, withLikedEventId eventId: String, completion: @escaping (Result<Void, any Error>) -> Void) {
        completion(.success(()))
    }
}
