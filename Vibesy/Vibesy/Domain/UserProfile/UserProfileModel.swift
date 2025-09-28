//
//  UserProfileModel.swift
//  Vibesy
//
//  Created by Alexander Cleoni on 12/15/24.
//

import Combine
import Foundation
import SwiftUI

@MainActor
class UserProfileModel: ObservableObject {
    @Published var userProfile: UserProfile = UserProfile()
    var errorMessage: String? // To handle and show errors in UI
    var status: String? = "Profile not fetched"
    @Published var matchedProfiles: [UserProfile] = []
    var currentMatchedProfile: UserProfile = UserProfile()
    
    private var cancellableBag = Set<AnyCancellable>()
    private let userProfileService: UserProfileService
    
    init(userProfileService: UserProfileService) {
        self.userProfileService = userProfileService
    }
    
    /// Fetches the user profile and updates `userProfile` and `userProfileImage`.
    func getUserProfile(userId: String, completion: @escaping (String) -> Void) {
        userProfileService.getUserProfile(userId: userId) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let (fetchedUserProfile)):
                        self?.userProfile = fetchedUserProfile
                        self?.errorMessage = nil // Clear any previous errors
                    completion("success")
                case .failure(let error):
                    self?.errorMessage = error.localizedDescription
                }
            }
        }
    }
    
    /// Updates the user profile and profile image in the backend.
    func updateUserProfile(userId: String, image: UIImage?) {
        userProfileService.updateUserProfile(userId: userId, image: image, userProfile: userProfile) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let updatedImageUrl):
                    self?.status = "Profile fetched"
                    self?.errorMessage = nil // Clear any previous errors
                    if let updatedImageUrl {
                        self?.userProfile.updateProfileImageUrl(updatedImageUrl)
                    }
                case .failure(let error):
                    self?.errorMessage = error.localizedDescription
                }
            }
        }
    }
    
    func getMatchedUsersProfiles(userId: String, userIds: Set<String>) {
        userProfileService.getMatchedUserProfiles(userId: userId, userIds: userIds) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let profilesWithImages):
                    // Map the profilesWithImages to extract only the UserProfile objects
                    let profiles = profilesWithImages.map { $0.0 }
                    self?.matchedProfiles = profiles
                    self?.status = "Matched profiles fetched successfully"
                    self?.errorMessage = nil // Clear any previous errors
                    
                case .failure(let error):
                    // Handle the error
                    self?.errorMessage = error.localizedDescription
                    self?.status = "Failed to fetch matched profiles"
                }
            }
        }
    }
    
    func resetMatchedUsersProfiles() {
        self.matchedProfiles = []
    }
}

extension UserProfileModel {
    static var mockUserProfileModel: UserProfileModel {
        let model = UserProfileModel(userProfileService: MockUserProfileService())
        model.userProfile = UserProfile(
            age: "32",
            bio: "You can catch me trying new restaurants and burning all the food off by dancing to live music.",
            fullName: "Aubree Dumas",
            interests: ["#music", "#food", "#dancing"],
            pronouns: "She/Her"
        )
        return model
    }
}
