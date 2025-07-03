//
//  UserProfileService.swift
//  Vibesy
//
//  Created by Alexander Cleoni on 12/15/24.
//

import Combine
import SwiftUI

protocol UserProfileService {
    func updateUserProfile(userId: String, image: UIImage?, userProfile: UserProfile, completion: @escaping (Result<String?, Error>) -> Void)
    func getUserProfile(userId: String, completion: @escaping (Result<(UserProfile), Error>) -> Void)
    func getMatchedUserProfiles(userId: String, userIds: Set<String>, completion: @escaping (Result<[(UserProfile, UIImage?)], Error>) -> Void)
}
