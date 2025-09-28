//
//  Guest.swift
//  FoundAVibe
//
//  Created by Alexander Cleoni on 12/13/24.
//
import Foundation
import SwiftUI
import os.log

// MARK: - Guest Domain Errors
enum GuestError: LocalizedError {
    case invalidName(String)
    case invalidRole(String)
    case invalidImageURL(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidName(let name):
            return "Invalid guest name: \(name). Name cannot be empty and must be less than 100 characters."
        case .invalidRole(let role):
            return "Invalid guest role: \(role). Role cannot be empty and must be less than 50 characters."
        case .invalidImageURL(let url):
            return "Invalid image URL: \(url)."
        }
    }
}

// MARK: - Enhanced Guest Model
struct Guest: Hashable, Codable, Identifiable {
    private static let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "Vibesy", category: "Guest")
    
    // MARK: - Constants
    private static let maxNameLength = 100
    private static let maxRoleLength = 50
    
    // MARK: - Properties
    let id: UUID
    private var _name: String
    private var _role: String
    private(set) var customRole: String?
    private(set) var imageUrl: String?
    private(set) var bio: String?
    private(set) var socialLinks: [String: String] = [:]
    private(set) var createdAt: Date = Date()
    private(set) var updatedAt: Date = Date()
    
    // MARK: - Computed Properties
    var name: String {
        get { _name }
        set {
            do {
                try setName(newValue)
            } catch {
                Self.logger.error("Failed to set guest name: \(error.localizedDescription)")
            }
        }
    }
    
    var role: String {
        get { _role }
        set {
            _role = newValue
            updateTimestamp()
        }
    }

    
    var getImageUrl: URL? {
        guard let url = imageUrl, !url.isEmpty else { return nil }
        return URL(string: url)
    }
    
    // MARK: - Initializer
    init(id: UUID = UUID(),
         name: String,
         role: String = "speaker",
         imageUrl: String? = nil) throws {
        
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
              name.count <= Self.maxNameLength else {
            throw GuestError.invalidName(name)
        }
        
        self.id = id
        self._name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        self._role = role
        self.imageUrl = imageUrl
    }
    
    // MARK: - Mutating Methods
    private mutating func setName(_ name: String) throws {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty && trimmed.count <= Self.maxNameLength else {
            throw GuestError.invalidName(name)
        }
        _name = trimmed
        updateTimestamp()
    }
    
    mutating func setCustomRole(_ role: String?) {
        if let role = role {
            let trimmed = role.trimmingCharacters(in: .whitespacesAndNewlines)
            self.customRole = trimmed.isEmpty ? nil : trimmed
        } else {
            self.customRole = nil
        }
        updateTimestamp()
    }
    
    mutating func updateImageURL(_ url: String?) throws {
        if let url = url, !url.isEmpty {
            guard URL(string: url) != nil else {
                throw GuestError.invalidImageURL(url)
            }
            self.imageUrl = url
        } else {
            self.imageUrl = nil
        }
        updateTimestamp()
    }
    
    mutating func updateBio(_ bio: String?) {
        self.bio = bio?.trimmingCharacters(in: .whitespacesAndNewlines)
        updateTimestamp()
    }
    
    mutating func addSocialLink(platform: String, url: String) {
        guard !platform.isEmpty, !url.isEmpty, URL(string: url) != nil else { return }
        socialLinks[platform] = url
        updateTimestamp()
    }
    
    mutating func removeSocialLink(platform: String) {
        socialLinks.removeValue(forKey: platform)
        updateTimestamp()
    }
    
    mutating func updateSocialLinks(_ links: [String: String]) {
        // Validate all URLs
        let validLinks = links.compactMapValues { url in
            URL(string: url) != nil ? url : nil
        }
        self.socialLinks = validLinks
        updateTimestamp()
    }
    
    // MARK: - Validation
    func validate() throws {
        if _name.isEmpty || _name.count > Self.maxNameLength {
            throw GuestError.invalidName(_name)
        }
        
        if let imageUrl = imageUrl, !imageUrl.isEmpty, URL(string: imageUrl) == nil {
            throw GuestError.invalidImageURL(imageUrl)
        }
        
        // Validate social links
        for (_, url) in socialLinks {
            if URL(string: url) == nil {
                throw GuestError.invalidImageURL(url)
            }
        }
    }
    
    // MARK: - Private Methods
    private mutating func updateTimestamp() {
        updatedAt = Date()
    }
    
    // MARK: - Hashable
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(_name)
        hasher.combine(_role)
        hasher.combine(customRole)
        hasher.combine(imageUrl)
        hasher.combine(bio)
        hasher.combine(socialLinks)
    }
    
    // MARK: - Equatable
    static func == (lhs: Guest, rhs: Guest) -> Bool {
        return lhs.id == rhs.id &&
        lhs._name == rhs._name &&
        lhs._role == rhs._role &&
        lhs.customRole == rhs.customRole &&
        lhs.imageUrl == rhs.imageUrl &&
        lhs.bio == rhs.bio &&
        lhs.socialLinks == rhs.socialLinks
    }
}
