//
//  EventImagePreloader.swift
//  Vibesy
//
//  Created by Alexander Cleoni on 3/6/25.
//

import Foundation
import Kingfisher

struct EventImagePreloader {
    
    /// Preloads guest images to warm the cache for faster display
    static func preloadGuestImages(for event: Event) {
        guard !event.guests.isEmpty else { return }
        
        // Collect valid URLs
        let guestImageUrls = event.guests.compactMap { guest -> URL? in
            guard let imageUrlString = guest.imageUrl,
                !imageUrlString.isEmpty,
                let imageUrl = URL(string: imageUrlString)
            else {
                print("Skipping guest \(guest.name) - no valid image URL")
                return nil
            }
            return imageUrl
        }
        
        guard !guestImageUrls.isEmpty else { return }
        
        print("Batch preloading \(guestImageUrls.count) guest images...")
        
        // Use ImagePrefetcher for efficient batch loading
        let prefetcher = ImagePrefetcher(urls: guestImageUrls) {
            skippedResources,
            failedResources,
            completedResources in
            print("Guest image preloading completed:")
            print("  - Completed: \(completedResources.count)")
            print("  - Failed: \(failedResources.count)")
            print("  - Skipped: \(skippedResources.count)")
        }
        
        // Start prefetching with higher priority
        prefetcher.start()
    }
    
    /// Preloads matched profile images to warm the cache for faster display
    static func preloadMatchedProfileImages(profiles: [UserProfile]) {
        guard !profiles.isEmpty else { return }
        
        // Collect valid profile image URLs
        let profileImageUrls = profiles.compactMap { profile -> URL? in
            guard !profile.profileImageUrl.isEmpty,
                let imageUrl = URL(string: profile.profileImageUrl)
            else {
                print(
                    "Skipping profile \(profile.fullName) - no valid image URL"
                )
                return nil
            }
            return imageUrl
        }
        
        guard !profileImageUrls.isEmpty else { return }
        
        print(
            "Batch preloading \(profileImageUrls.count) matched profile images..."
        )
        
        // Use ImagePrefetcher for efficient batch loading
        let prefetcher = ImagePrefetcher(urls: profileImageUrls) {
            skippedResources,
            failedResources,
            completedResources in
            print("Profile image preloading completed:")
            print("  - Completed: \(completedResources.count)")
            print("  - Failed: \(failedResources.count)")
            print("  - Skipped: \(skippedResources.count)")
        }
        
        // Start prefetching
        prefetcher.start()
    }
}
