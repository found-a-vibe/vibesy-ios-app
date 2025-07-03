//
//  UserProfile.swift
//  Vibesy
//
//  Created by Alexander Cleoni on 12/15/24.
//

import Foundation

struct UserProfile: Equatable, Hashable {
    var uid: String? = nil
    var age: String = ""
    var bio: String = ""
    var fullName: String = ""
    var interests: [String] = []
    var pronouns: String = ""
    var profileImageUrl: String = ""
    var friendRequests: [String: Any] = [:]
    var friends: [String: Any] = [:]
    
    // Manually define hashing, excluding `friendRequests`
    func hash(into hasher: inout Hasher) {
        hasher.combine(uid)
        hasher.combine(age)
        hasher.combine(bio)
        hasher.combine(fullName)
        hasher.combine(interests)
        hasher.combine(pronouns)
        hasher.combine(profileImageUrl)
    }
    
    // Manually implement Equatable
    static func == (lhs: UserProfile, rhs: UserProfile) -> Bool {
        return lhs.uid == rhs.uid &&
        lhs.age == rhs.age &&
        lhs.bio == rhs.bio &&
        lhs.fullName == rhs.fullName &&
        lhs.interests == rhs.interests &&
        lhs.pronouns == rhs.pronouns &&
        lhs.profileImageUrl == rhs.profileImageUrl
        // Ignoring `friendRequests` because [String: Any] is not equatable
    }
}
