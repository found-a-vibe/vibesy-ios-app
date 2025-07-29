//
//  EventParser.swift
//  Vibesy
//
//  Created by Alexander Cleoni on 1/16/25.
//
import Foundation
import SwiftUI

struct EventParser {
    
    func parse(from data: [String: Any]) -> Event? {
        // Parse required fields
        guard let id = parseUUID(from: data["id"]),
              let title = data["title"] as? String,
              let description = data["description"] as? String,
              let date = data["date"] as? String,
              let timeRange = data["timeRange"] as? String,
              let location = data["location"] as? String,
              let createdBy = data["createdBy"] as? String else {
            print("Invalid event data: \(data)")
            return nil
        }
        
        // Parse optional fields
        let hashtags = parseStringArray(from: data["hashtags"])
        let category = data["category"] as? String
        let likes = parseStringSet(from: data["likes"])
        let reservations = parseStringSet(from: data["reservations"])
        let interactions = parseStringSet(from: data["interactions"])
        
        // Parse guests
        let guests = (data["guests"] as? [[String: Any]])?.compactMap { guestDict -> Guest? in
            guard let guestID = parseUUID(from: guestDict["id"]),
                  let name = guestDict["name"] as? String,
                  let role = guestDict["role"] as? String,
                  let imageUrlString = guestDict["imageUrl"] as? String else { return nil }
            return Guest(id: guestID, name: name, role: role, image: nil, imageUrl: imageUrlString) // Image loading handled elsewhere
        } ?? []
        
        // Parse price details
        let priceDetails = (data["priceDetails"] as? [[String: Any]])?.compactMap { priceDict -> PriceDetails? in
            guard let title = priceDict["title"] as? String,
                  let price = priceDict["price"] as? String else { return nil }
            
            let link = priceDict["link"] as? String
            
            return PriceDetails(title: title, price: price, link: link)
        } ?? []
                
        // Parse image URLs
        let imageUrls = parseStringArray(from: data["images"])
        
        // Create and return Event
        return Event(
            id: id,
            title: title,
            description: description,
            date: date,
            timeRange: timeRange,
            location: location,
            images: imageUrls,
            hashtags: hashtags,
            guests: guests,
            priceDetails: priceDetails,
            likes: likes,
            reservations: reservations,
            interactions: interactions,
            createdBy: createdBy,
            category: category
        )
    }
    
    // Helper to safely parse UUID
    private func parseUUID(from value: Any?) -> UUID? {
        guard let string = value as? String else { return nil }
        return UUID(uuidString: string)
    }
    
    // Helper to parse an array of strings safely
    private func parseStringArray(from value: Any?) -> [String] {
        return (value as? [String]) ?? []
    }
    
    // Helper to parse a set of strings safely
    private func parseStringSet(from value: Any?) -> Set<String> {
        return Set((value as? [Any])?.compactMap { $0 as? String } ?? [])
    }
}
