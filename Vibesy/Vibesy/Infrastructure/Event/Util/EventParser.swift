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
              let location = data["location"] as? String else {
            print("Invalid event data: \(data)")
            return nil
        }
        
        // Parse createdBy - can be empty for platform-generated events
        let createdBy = data["createdBy"] as? String ?? ""
        
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
            return try? Guest(id: guestID, name: name, role: role, imageUrl: imageUrlString) // Image loading handled elsewhere
        } ?? []
        
        // Parse price details
        let priceDetails = (data["priceDetails"] as? [[String: Any]])?.compactMap { priceDict -> PriceDetails? in
            guard let title = priceDict["title"] as? String else { return nil }
            
            // Handle price as either String or Number from Firebase
            let priceDecimal: Decimal
            if let priceString = priceDict["price"] as? String {
                guard let decimal = Decimal(string: priceString) else { return nil }
                priceDecimal = decimal
            } else if let priceNumber = priceDict["price"] as? NSNumber {
                priceDecimal = priceNumber.decimalValue
            } else {
                return nil
            }
            
            let link = priceDict["link"] as? String
            let currencyString = priceDict["currency"] as? String ?? "USD"
            let typeString = priceDict["type"] as? String ?? "fixed"
            
            let currency = Currency(rawValue: currencyString) ?? .usd
            let type = PriceType(rawValue: typeString) ?? .fixed
            
            do {
                var priceDetail = try PriceDetails(
                    title: title,
                    price: priceDecimal,
                    currency: currency,
                    type: type,
                    link: link
                )
                
                // Set Stripe price ID if available
                if let stripePriceId = priceDict["stripePriceId"] as? String {
                    priceDetail.setStripePriceId(stripePriceId)
                }
                
                return priceDetail
            } catch {
                print("Error creating PriceDetails: \(error)")
                return nil
            }
        } ?? []
                
        // Parse image URLs
        let imageUrls = parseStringArray(from: data["images"])
        
        // Create and return Event - using the correct initializer
//        guard let eventCategory = category.flatMap({ EventCategory(rawValue: $0) }) else {
//            return nil // Invalid category
//        }
        
        do {
            var event = try Event(
                id: id,
                title: title,
                description: description,
                date: date,
                timeRange: timeRange,
                location: location,
//                category: eventCategory,
                createdBy: createdBy
            )
            
            // Add guests and price details after creation since they're not part of the initializer
            for guest in guests {
                try? event.addGuest(guest)
            }
            
            for priceDetail in priceDetails {
                event.addPriceDetail(priceDetail)
            }
            
            // Set hashtags
            event.hashtags = hashtags
            
            // Set image URLs
            event.setImageURLs(imageUrls)
            
            // Add interactions (likes, reservations, etc.) 
            for userID in likes {
                event.addLike(from: userID)
            }
            for userID in reservations {
                event.addReservation(from: userID)
            }
            for userID in interactions {
                event.addInteraction(from: userID)
            }
            
            // Set Stripe information if available
            if let stripeProductId = data["stripeProductId"] as? String,
               let stripeConnectedAccountId = data["stripeConnectedAccountId"] as? String {
                event.setStripeProductInfo(
                    productId: stripeProductId,
                    connectedAccountId: stripeConnectedAccountId
                )
            }
            
            return event
            
        } catch {
            print("Error creating event: \(error)")
            return nil
        }
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
