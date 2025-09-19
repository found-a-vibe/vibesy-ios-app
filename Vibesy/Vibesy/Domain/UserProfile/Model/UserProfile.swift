//
//  UserProfile.swift
//  Vibesy
//
//  Created by Alexander Cleoni on 12/15/24.
//

import Foundation
import os.log

// MARK: - Domain Errors
enum UserProfileError: LocalizedError {
    case invalidAge(String)
    case bioTooLong(Int)
    case nameEmpty
    case invalidEmail(String)
    case invalidUID(String)
    case tooManyInterests(Int)
    
    var errorDescription: String? {
        switch self {
        case .invalidAge(let age):
            return "Invalid age format: \(age). Age must be a number between 13 and 120."
        case .bioTooLong(let count):
            return "Bio is too long: \(count) characters. Maximum allowed is 500."
        case .nameEmpty:
            return "Full name cannot be empty."
        case .invalidEmail(let email):
            return "Invalid email format: \(email)"
        case .invalidUID(let uid):
            return "Invalid user ID: \(uid)"
        case .tooManyInterests(let count):
            return "Too many interests: \(count). Maximum allowed is 10."
        }
    }
}

// MARK: - Type-safe Friend Request Structure
struct FriendRequest: Codable, Equatable, Hashable {
    let id: String
    let senderUID: String
    let senderName: String
    let senderImageURL: String?
    let timestamp: Date
    let status: FriendRequestStatus
    
    enum FriendRequestStatus: String, Codable, CaseIterable {
        case pending = "pending"
        case accepted = "accepted"
        case declined = "declined"
    }
}

// MARK: - Type-safe Friend Structure
struct Friend: Codable, Equatable, Hashable {
    let uid: String
    let name: String
    let imageURL: String?
    let addedDate: Date
    let isOnline: Bool
}

// MARK: - Enhanced UserProfile with validation
struct UserProfile: Equatable, Hashable, Codable {
    private static let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "Vibesy", category: "UserProfile")
    
    // MARK: - Constants
    private static let maxBioLength = 500
    private static let maxInterestsCount = 10
    private static let minAge = 13
    private static let maxAge = 120
    
    // MARK: - Core Properties
    private(set) var uid: String?
    private var _age: String = ""
    private var _bio: String = ""
    private var _fullName: String = ""
    private var _interests: [String] = []
    private(set) var pronouns: String = ""
    private(set) var profileImageUrl: String = ""
    private(set) var friendRequests: [String: FriendRequest] = [:]
    private(set) var friends: [String: Friend] = [:]
    
    // MARK: - Business Properties
    private(set) var stripeConnectId: String?
    private(set) var stripeOnboardingComplete: Bool = false
    private(set) var isHost: Bool = false
    
    // MARK: - Metadata
    private(set) var createdAt: Date = Date()
    private(set) var updatedAt: Date = Date()
    
    // MARK: - Initializers
    init(uid: String? = nil,
         age: String = "",
         bio: String = "",
         fullName: String = "",
         interests: [String] = [],
         pronouns: String = "",
         profileImageUrl: String = "",
         friendRequests: [String: FriendRequest] = [:],
         friends: [String: Friend] = [:],
         stripeConnectId: String? = nil,
         stripeOnboardingComplete: Bool = false,
         isHost: Bool = false) {
        
        self.uid = uid
        self._age = age
        self._bio = bio
        self._fullName = fullName
        self._interests = interests
        self.pronouns = pronouns
        self.profileImageUrl = profileImageUrl
        self.friendRequests = friendRequests
        self.friends = friends
        self.stripeConnectId = stripeConnectId
        self.stripeOnboardingComplete = stripeOnboardingComplete
        self.isHost = isHost
    }
    
    // MARK: - Computed Properties with Validation
    var age: String {
        get { _age }
        set {
            if isValidAge(newValue) {
                _age = newValue
                updateTimestamp()
            } else {
                Self.logger.warning("Attempted to set invalid age: \(newValue)")
            }
        }
    }
    
    var bio: String {
        get { _bio }
        set {
            if newValue.count <= Self.maxBioLength {
                _bio = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
                updateTimestamp()
            } else {
                Self.logger.warning("Attempted to set bio that's too long: \(newValue.count) characters")
            }
        }
    }
    
    var fullName: String {
        get { _fullName }
        set {
            let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                _fullName = trimmed
                updateTimestamp()
            } else {
                Self.logger.warning("Attempted to set empty full name")
            }
        }
    }
    
    var interests: [String] {
        get { _interests }
        set {
            if newValue.count <= Self.maxInterestsCount {
                // Clean and validate interests
                let cleanInterests = newValue
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }
                    .map { interest in
                        // Ensure hashtag format
                        interest.hasPrefix("#") ? interest : "#\(interest)"
                    }
                _interests = Array(Set(cleanInterests)) // Remove duplicates
                updateTimestamp()
            } else {
                Self.logger.warning("Attempted to set too many interests: \(newValue.count)")
            }
        }
    }
    
    // MARK: - Validation Methods
    func validate() throws {
        if let uid = uid, uid.isEmpty {
            throw UserProfileError.invalidUID(uid)
        }
        
        if !_fullName.isEmpty && _fullName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            throw UserProfileError.nameEmpty
        }
        
        if !_age.isEmpty && !isValidAge(_age) {
            throw UserProfileError.invalidAge(_age)
        }
        
        if _bio.count > Self.maxBioLength {
            throw UserProfileError.bioTooLong(_bio.count)
        }
        
        if _interests.count > Self.maxInterestsCount {
            throw UserProfileError.tooManyInterests(_interests.count)
        }
    }
    
    private func isValidAge(_ ageString: String) -> Bool {
        guard let age = Int(ageString), age >= Self.minAge, age <= Self.maxAge else {
            return false
        }
        return true
    }
    
    // MARK: - Computed Properties
    var isComplete: Bool {
        !_fullName.isEmpty && !_age.isEmpty && !_bio.isEmpty && !_interests.isEmpty
    }
    
    var displayName: String {
        _fullName.isEmpty ? "Unknown User" : _fullName
    }
    
    var friendCount: Int {
        friends.count
    }
    
    var pendingFriendRequestCount: Int {
        friendRequests.values.filter { $0.status == .pending }.count
    }
    
    // MARK: - Mutating Methods
    mutating func setUID(_ uid: String) throws {
        guard !uid.isEmpty else {
            throw UserProfileError.invalidUID(uid)
        }
        self.uid = uid
        updateTimestamp()
    }
    
    mutating func updatePronouns(_ pronouns: String) {
        self.pronouns = pronouns.trimmingCharacters(in: .whitespacesAndNewlines)
        updateTimestamp()
    }
    
    mutating func updateProfileImageUrl(_ url: String) {
        self.profileImageUrl = url
        updateTimestamp()
    }
    
    mutating func updateStripeInfo(connectId: String?, onboardingComplete: Bool, isHost: Bool) {
        self.stripeConnectId = connectId
        self.stripeOnboardingComplete = onboardingComplete
        self.isHost = isHost
        updateTimestamp()
    }
    
    mutating func addFriendRequest(_ request: FriendRequest) {
        friendRequests[request.id] = request
        updateTimestamp()
    }
    
    mutating func removeFriendRequest(withId id: String) {
        friendRequests.removeValue(forKey: id)
        updateTimestamp()
    }
    
    mutating func addFriend(_ friend: Friend) {
        friends[friend.uid] = friend
        updateTimestamp()
    }
    
    mutating func removeFriend(withUID uid: String) {
        friends.removeValue(forKey: uid)
        updateTimestamp()
    }
    
    private mutating func updateTimestamp() {
        updatedAt = Date()
    }
    
    // MARK: - Hashable
    func hash(into hasher: inout Hasher) {
        hasher.combine(uid)
        hasher.combine(_age)
        hasher.combine(_bio)
        hasher.combine(_fullName)
        hasher.combine(_interests)
        hasher.combine(pronouns)
        hasher.combine(profileImageUrl)
        hasher.combine(stripeConnectId)
        hasher.combine(stripeOnboardingComplete)
        hasher.combine(isHost)
        hasher.combine(friendRequests)
        hasher.combine(friends)
    }
    
    // MARK: - Equatable
    static func == (lhs: UserProfile, rhs: UserProfile) -> Bool {
        return lhs.uid == rhs.uid &&
        lhs._age == rhs._age &&
        lhs._bio == rhs._bio &&
        lhs._fullName == rhs._fullName &&
        lhs._interests == rhs._interests &&
        lhs.pronouns == rhs.pronouns &&
        lhs.profileImageUrl == rhs.profileImageUrl &&
        lhs.stripeConnectId == rhs.stripeConnectId &&
        lhs.stripeOnboardingComplete == rhs.stripeOnboardingComplete &&
        lhs.isHost == rhs.isHost &&
        lhs.friendRequests == rhs.friendRequests &&
        lhs.friends == rhs.friends
    }
}
