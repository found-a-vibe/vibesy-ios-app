//
//  Event.swift
//  FoundAVibe
//
//  Created by Alexander Cleoni on 11/12/24.
//

import Foundation
import SwiftUI

enum EventStatus: String, CaseIterable {
    case likedEvents = "likedEvents"
    case postedEvents = "postedEvents"
    case reservedEvents = "reservedEvents"
    case attendedEvents = "attendedEvents"
}

struct Event: Identifiable, Hashable {
    let id: UUID
    var title: String
    var description: String
    var date: String
    var timeRange: String
    var location: String
    var images: [String] = []
    var newImages: [UIImage]? = []
    var hashtags: [String] = []
    var guests: [Guest] = []
    var priceDetails: [PriceDetails] = []
    var likes: Set<String> = []
    var interactions: Set<String> = []
    var createdBy: String
    var category: String?

    mutating func addImage(_ image: UIImage) {
        newImages?.append(image)
    }
    
    mutating func removeImage(_ image: UIImage) {
        newImages?.removeAll { $0 == image }
    }
    
    func getImages() -> [String] {
        return images
    }
    
    mutating func addHashtag(_ hashtag: String) {
        hashtags.append(hashtag)
    }
    
    mutating func removeHashtag(_ hashtag: String) {
        hashtags.removeAll { $0 == hashtag }
    }
    
    func getHashtags() -> [String] {
        return hashtags
    }
    
    mutating func addGuest(_ guest: Guest) {
        guests.append(guest)
    }
    
    mutating func removeGuest(byId id: UUID) {
        guests.removeAll { $0.id == id }
    }
    
    func getGuests() -> [Guest] {
        return guests
    }
    
    func getLikes() -> Set<String> {
        return likes
    }
    
    func getInteractions() -> Set<String> {
        return interactions
    }
}

