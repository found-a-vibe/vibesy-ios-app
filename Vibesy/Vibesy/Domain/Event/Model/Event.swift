//
//  Event.swift
//  FoundAVibe
//
//  Created by Alexander Cleoni on 11/12/24.
//

import Foundation
import SwiftUI
import os.log

// MARK: - Event Domain Errors
enum EventError: LocalizedError {
    case invalidTitle(String)
    case invalidDescription(String)
    case invalidDate(String)
    case invalidTimeRange(String)
    case invalidLocation(String)
    case invalidCategory(String)
    case tooManyImages(Int)
    case tooManyGuests(Int)
    case tooManyHashtags(Int)
    case duplicateGuest(UUID)
    case guestNotFound(UUID)
    case invalidCreatorUID(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidTitle(let title):
            return "Invalid event title: \(title). Title must be between 1-100 characters."
        case .invalidDescription(let description):
            return "Invalid event description: \(description). Description must be between 1-1000 characters."
        case .invalidDate(let date):
            return "Invalid event date: \(date). Date must be in the future."
        case .invalidTimeRange(let time):
            return "Invalid time range: \(time)."
        case .invalidLocation(let location):
            return "Invalid location: \(location). Location cannot be empty."
        case .invalidCategory(let category):
            return "Invalid category: \(category)."
        case .tooManyImages(let count):
            return "Too many images: \(count). Maximum allowed is 10."
        case .tooManyGuests(let count):
            return "Too many guests: \(count). Maximum allowed is 100."
        case .tooManyHashtags(let count):
            return "Too many hashtags: \(count). Maximum allowed is 10."
        case .duplicateGuest(let id):
            return "Guest with ID \(id) already exists."
        case .guestNotFound(let id):
            return "Guest with ID \(id) not found."
        case .invalidCreatorUID(let uid):
            return "Invalid creator UID: \(uid). Creator UID cannot be empty."
        }
    }
}

// MARK: - Event Status
enum EventStatus: String, CaseIterable, Codable {
    case likedEvents = "likedEvents"
    case postedEvents = "postedEvents"
    case reservedEvents = "reservedEvents"
    case attendedEvents = "attendedEvents"
    
    var displayName: String {
        switch self {
        case .likedEvents: return "Liked Events"
        case .postedEvents: return "Posted Events"
        case .reservedEvents: return "Reserved Events"
        case .attendedEvents: return "Attended Events"
        }
    }
}

// MARK: - Enhanced Event Model
struct Event: Identifiable, Hashable, Codable {
    private static let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "Vibesy", category: "Event")
    
    // MARK: - Constants
    private static let maxTitleLength = 100
    private static let maxDescriptionLength = 1000
    private static let maxImages = 10
    private static let maxGuests = 100
    private static let maxHashtags = 10
    
    // MARK: - Core Properties
    let id: UUID
    private var _title: String = ""
    private var _description: String = ""
    private var _date: String = ""
    private var _timeRange: String = ""
    private var _location: String = ""
    
    // MARK: - Media and Content
    private(set) var images: [String] = []
    private(set) var newImages: [UIImage] = []
    private var _hashtags: [String] = []
    private var _guests: [Guest] = []
    private(set) var priceDetails: [PriceDetails] = []
    
    // MARK: - Interactions
    private(set) var likes: Set<String> = []
    private(set) var reservations: Set<String> = []
    private(set) var interactions: Set<String> = []
    
    // MARK: - Metadata
    private(set) var createdBy: String
    private(set) var createdAt: Date = Date()
    private(set) var updatedAt: Date = Date()
    
    // MARK: - Stripe Integration
    private(set) var stripeProductId: String?
    private(set) var stripeConnectedAccountId: String?
    
    // MARK: - Computed Properties
    var isUserGenerated: Bool {
        !createdBy.isEmpty
    }
    
    var isPlatformGenerated: Bool {
        createdBy.isEmpty
    }
    
    var isComplete: Bool {
        !_title.isEmpty && !_description.isEmpty && !_date.isEmpty && 
        !_timeRange.isEmpty && !_location.isEmpty && (isUserGenerated ? !createdBy.isEmpty : true)
    }
    
    var likeCount: Int { likes.count }
    var reservationCount: Int { reservations.count }
    var interactionCount: Int { interactions.count }
    var guestCount: Int { _guests.count }
    var hashtagCount: Int { _hashtags.count }
    
    // MARK: - Initializer
    init(id: UUID = UUID(),
         title: String = "",
         description: String = "",
         date: String = "",
         timeRange: String = "",
         location: String = "",
         createdBy: String = "") throws {
        
        // Allow empty createdBy for platform-generated events
        // Only validate if createdBy is provided but invalid
        
        self.id = id
        self.createdBy = createdBy
        
        // Set properties with validation
        try setTitle(title)
        try setDescription(description)
        try setDate(date)
        try setTimeRange(timeRange)
        try setLocation(location)
    }
    
    // MARK: - Empty Initializer for UI State
    /// Creates an empty Event for use as initial UI state
    static func empty(id: UUID = UUID(), createdBy: String = "") -> Event {
        return Event(__createEmpty: id, createdBy: createdBy)
    }
    
    /// Private initializer that bypasses validation for creating empty events
    private init(__createEmpty id: UUID, createdBy: String) {
        self.id = id
        self.createdBy = createdBy
        // All other properties are already initialized with empty defaults
    }
    
    // MARK: - Property Setters with Validation
    var title: String {
        get { _title }
        set {
            do {
                try setTitle(newValue)
            } catch {
                Self.logger.error("Failed to set title: \(error.localizedDescription)")
            }
        }
    }
    
    private mutating func setTitle(_ title: String) throws {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty && trimmed.count <= Self.maxTitleLength else {
            throw EventError.invalidTitle(title)
        }
        _title = trimmed
        updateTimestamp()
    }
    
    var description: String {
        get { _description }
        set {
            do {
                try setDescription(newValue)
            } catch {
                Self.logger.error("Failed to set description: \(error.localizedDescription)")
            }
        }
    }
    
    private mutating func setDescription(_ description: String) throws {
        let trimmed = description.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty && trimmed.count <= Self.maxDescriptionLength else {
            throw EventError.invalidDescription(description)
        }
        _description = trimmed
        updateTimestamp()
    }
    
    var date: String {
        get { _date }
        set {
            do {
                try setDate(newValue)
            } catch {
                Self.logger.error("Failed to set date: \(error.localizedDescription)")
            }
        }
    }
    
    private mutating func setDate(_ date: String) throws {
        let trimmed = date.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw EventError.invalidDate(date)
        }
        _date = trimmed
        updateTimestamp()
    }
    
    var timeRange: String {
        get { _timeRange }
        set {
            do {
                try setTimeRange(newValue)
            } catch {
                Self.logger.error("Failed to set time range: \(error.localizedDescription)")
            }
        }
    }
    
    private mutating func setTimeRange(_ timeRange: String) throws {
        let trimmed = timeRange.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw EventError.invalidTimeRange(timeRange)
        }
        _timeRange = trimmed
        updateTimestamp()
    }
    
    var location: String {
        get { _location }
        set {
            do {
                try setLocation(newValue)
            } catch {
                Self.logger.error("Failed to set location: \(error.localizedDescription)")
            }
        }
    }
    
    private mutating func setLocation(_ location: String) throws {
        let trimmed = location.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw EventError.invalidLocation(location)
        }
        _location = trimmed
        updateTimestamp()
    }
    
    // MARK: - Image Management
    mutating func addImage(_ image: UIImage) throws {
        guard newImages.count < Self.maxImages else {
            throw EventError.tooManyImages(newImages.count + 1)
        }
        newImages.append(image)
        updateTimestamp()
    }
    
    mutating func removeImage(_ image: UIImage) {
        newImages.removeAll { $0 == image }
        updateTimestamp()
    }
    
    mutating func addImageURL(_ url: String) throws {
        guard images.count < Self.maxImages else {
            throw EventError.tooManyImages(images.count + 1)
        }
        guard !images.contains(url) else { return }
        images.append(url)
        updateTimestamp()
    }
    
    mutating func removeImageURL(_ url: String) {
        images.removeAll { $0 == url }
        updateTimestamp()
    }
    
    mutating func setImageURLs(_ urls: [String]) {
        images = urls
        updateTimestamp()
    }
    
    // MARK: - Hashtag Management
    var hashtags: [String] {
        get { _hashtags }
        set {
            do {
                try setHashtags(newValue)
            } catch {
                Self.logger.error("Failed to set hashtags: \(error.localizedDescription)")
            }
        }
    }
    
    private mutating func setHashtags(_ hashtags: [String]) throws {
        guard hashtags.count <= Self.maxHashtags else {
            throw EventError.tooManyHashtags(hashtags.count)
        }
        
        let cleanHashtags = hashtags
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .map { hashtag in
                hashtag.hasPrefix("#") ? hashtag : "#\(hashtag)"
            }
        
        _hashtags = Array(Set(cleanHashtags)) // Remove duplicates
        updateTimestamp()
    }
    
    mutating func addHashtag(_ hashtag: String) throws {
        guard _hashtags.count < Self.maxHashtags else {
            throw EventError.tooManyHashtags(_hashtags.count + 1)
        }
        
        let cleanHashtag = hashtag.trimmingCharacters(in: .whitespacesAndNewlines)
        let formattedHashtag = cleanHashtag.hasPrefix("#") ? cleanHashtag : "#\(cleanHashtag)"
        
        if !_hashtags.contains(formattedHashtag) {
            _hashtags.append(formattedHashtag)
            updateTimestamp()
        }
    }
    
    mutating func removeHashtag(_ hashtag: String) {
        _hashtags.removeAll { $0 == hashtag }
        updateTimestamp()
    }
    
    // MARK: - Guest Management
    var guests: [Guest] {
        get { _guests }
    }
    
    mutating func addGuest(_ guest: Guest) throws {
        guard _guests.count < Self.maxGuests else {
            throw EventError.tooManyGuests(_guests.count + 1)
        }
        
        guard !_guests.contains(where: { $0.id == guest.id }) else {
            throw EventError.duplicateGuest(guest.id)
        }
        
        _guests.append(guest)
        updateTimestamp()
    }
    
    mutating func removeGuest(byId id: UUID) throws {
        guard let index = _guests.firstIndex(where: { $0.id == id }) else {
            throw EventError.guestNotFound(id)
        }
        _guests.remove(at: index)
        updateTimestamp()
    }
    
    mutating func updateGuest(_ guest: Guest) throws {
        guard let index = _guests.firstIndex(where: { $0.id == guest.id }) else {
            throw EventError.guestNotFound(guest.id)
        }
        _guests[index] = guest
        updateTimestamp()
    }
    
    // MARK: - Price Details Management
    mutating func addPriceDetail(_ detail: PriceDetails) {
        priceDetails.append(detail)
        updateTimestamp()
    }
    
    mutating func removePriceDetail(withTitle title: String) {
        priceDetails.removeAll { $0.title == title }
        updateTimestamp()
    }
    
    mutating func updatePriceDetails(_ details: [PriceDetails]) {
        priceDetails = details
        updateTimestamp()
    }
    
    // MARK: - Interaction Management
    mutating func addLike(from userID: String) {
        likes.insert(userID)
        updateTimestamp()
    }
    
    mutating func removeLike(from userID: String) {
        likes.remove(userID)
        updateTimestamp()
    }
    
    mutating func addReservation(from userID: String) {
        reservations.insert(userID)
        updateTimestamp()
    }
    
    mutating func removeReservation(from userID: String) {
        reservations.remove(userID)
        updateTimestamp()
    }
    
    mutating func addInteraction(from userID: String) {
        interactions.insert(userID)
        updateTimestamp()
    }
    
    mutating func removeInteraction(from userID: String) {
        interactions.remove(userID)
        updateTimestamp()
    }
    
    // MARK: - Query Methods
    func isLikedBy(_ userID: String) -> Bool {
        likes.contains(userID)
    }
    
    func isReservedBy(_ userID: String) -> Bool {
        reservations.contains(userID)
    }
    
    func hasInteractionFrom(_ userID: String) -> Bool {
        interactions.contains(userID)
    }
    
    func isCreatedBy(_ userID: String) -> Bool {
        createdBy == userID
    }
    
    // MARK: - Stripe Management
    mutating func setStripeProductInfo(productId: String, connectedAccountId: String) {
        stripeProductId = productId
        stripeConnectedAccountId = connectedAccountId
        updateTimestamp()
    }
    
    mutating func clearStripeProductInfo() {
        stripeProductId = nil
        stripeConnectedAccountId = nil
        updateTimestamp()
    }
    
    // MARK: - Validation
    func validate() throws {
        if _title.isEmpty || _title.count > Self.maxTitleLength {
            throw EventError.invalidTitle(_title)
        }
        
        if _description.isEmpty || _description.count > Self.maxDescriptionLength {
            throw EventError.invalidDescription(_description)
        }
        
        if _date.isEmpty {
            throw EventError.invalidDate(_date)
        }
        
        if _timeRange.isEmpty {
            throw EventError.invalidTimeRange(_timeRange)
        }
        
        if _location.isEmpty {
            throw EventError.invalidLocation(_location)
        }
        
        // Only validate createdBy for user-generated events
        // Platform-generated events can have empty createdBy
        
        if images.count + newImages.count > Self.maxImages {
            throw EventError.tooManyImages(images.count + newImages.count)
        }
        
        if _guests.count > Self.maxGuests {
            throw EventError.tooManyGuests(_guests.count)
        }
        
        if _hashtags.count > Self.maxHashtags {
            throw EventError.tooManyHashtags(_hashtags.count)
        }
    }
    
    // MARK: - Private Methods
    private mutating func updateTimestamp() {
        updatedAt = Date()
    }
    
    // MARK: - Hashable (Excluding newImages as UIImage is not Hashable)
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(_title)
        hasher.combine(_description)
        hasher.combine(_date)
        hasher.combine(_timeRange)
        hasher.combine(_location)
        hasher.combine(images)
        hasher.combine(_hashtags)
        hasher.combine(_guests)
        hasher.combine(priceDetails)
        hasher.combine(likes)
        hasher.combine(reservations)
        hasher.combine(interactions)
        hasher.combine(createdBy)
    }
    
    // MARK: - Equatable (Excluding newImages)
    static func == (lhs: Event, rhs: Event) -> Bool {
        return lhs.id == rhs.id &&
        lhs._title == rhs._title &&
        lhs._description == rhs._description &&
        lhs._date == rhs._date &&
        lhs._timeRange == rhs._timeRange &&
        lhs._location == rhs._location &&
        lhs.images == rhs.images &&
        lhs._hashtags == rhs._hashtags &&
        lhs._guests == rhs._guests &&
        lhs.priceDetails == rhs.priceDetails &&
        lhs.likes == rhs.likes &&
        lhs.reservations == rhs.reservations &&
        lhs.interactions == rhs.interactions &&
        lhs.createdBy == rhs.createdBy
    }
    
    // MARK: - Custom Codable Implementation
    private enum CodingKeys: String, CodingKey {
        case id, _title, _description, _date, _timeRange, _location, _category
        case images, _hashtags, _guests, priceDetails
        case likes, reservations, interactions
        case createdBy, createdAt, updatedAt
        case stripeProductId, stripeConnectedAccountId
        // Note: newImages is excluded from coding as UIImage isn't Codable
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        id = try container.decode(UUID.self, forKey: .id)
        _title = try container.decode(String.self, forKey: ._title)
        _description = try container.decode(String.self, forKey: ._description)
        _date = try container.decode(String.self, forKey: ._date)
        _timeRange = try container.decode(String.self, forKey: ._timeRange)
        _location = try container.decode(String.self, forKey: ._location)
        
        images = try container.decode([String].self, forKey: .images)
        _hashtags = try container.decode([String].self, forKey: ._hashtags)
        _guests = try container.decode([Guest].self, forKey: ._guests)
        priceDetails = try container.decode([PriceDetails].self, forKey: .priceDetails)
        
        likes = try container.decode(Set<String>.self, forKey: .likes)
        reservations = try container.decode(Set<String>.self, forKey: .reservations)
        interactions = try container.decode(Set<String>.self, forKey: .interactions)
        
        createdBy = try container.decode(String.self, forKey: .createdBy)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
        
        // Stripe fields (optional)
        stripeProductId = try container.decodeIfPresent(String.self, forKey: .stripeProductId)
        stripeConnectedAccountId = try container.decodeIfPresent(String.self, forKey: .stripeConnectedAccountId)
        
        // newImages is not decoded - remains empty array
        newImages = []
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encode(id, forKey: .id)
        try container.encode(_title, forKey: ._title)
        try container.encode(_description, forKey: ._description)
        try container.encode(_date, forKey: ._date)
        try container.encode(_timeRange, forKey: ._timeRange)
        try container.encode(_location, forKey: ._location)
        
        try container.encode(images, forKey: .images)
        try container.encode(_hashtags, forKey: ._hashtags)
        try container.encode(_guests, forKey: ._guests)
        try container.encode(priceDetails, forKey: .priceDetails)
        
        try container.encode(likes, forKey: .likes)
        try container.encode(reservations, forKey: .reservations)
        try container.encode(interactions, forKey: .interactions)
        
        try container.encode(createdBy, forKey: .createdBy)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(updatedAt, forKey: .updatedAt)
        
        // Stripe fields (optional)
        try container.encodeIfPresent(stripeProductId, forKey: .stripeProductId)
        try container.encodeIfPresent(stripeConnectedAccountId, forKey: .stripeConnectedAccountId)
        
        // newImages is not encoded as UIImage isn't Codable
    }
}

