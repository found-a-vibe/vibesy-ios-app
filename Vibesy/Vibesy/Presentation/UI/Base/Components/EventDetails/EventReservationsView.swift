//
//  EventReservationsView.swift
//  Vibesy
//
//  Created by Alexander Cleoni on 3/6/25.
//

import Kingfisher
import SwiftUI

// MARK: - Event Reservations View
struct EventReservationsView: View {
    @SwiftUI.Environment(\.dismiss) private var dismiss
    
    let event: Event
    let reservedUserProfiles: [UserProfile]
    
    var body: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 20) {
                // Header Section
                VStack(alignment: .leading, spacing: 12) {
                    Text("Event Reservations")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.espresso)
                    
                    Text(event.title)
                        .font(.headline)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal)
                .padding(.top)
                
                // Reservation Count
                HStack {
                    Image(systemName: "person.2.fill")
                        .foregroundColor(.goldenBrown)
                    Text(
                        "\(reservedUserProfiles.count) \(reservedUserProfiles.count == 1 ? "Reservation" : "Reservations")"
                    )
                    .font(.subheadline)
                    .fontWeight(.medium)
                }
                .padding(.horizontal)
                
                // Reservations List
                if reservedUserProfiles.isEmpty {
                    emptyStateView
                } else {
                    reservationsList
                }
                
                Spacer()
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(.espresso)
                }
            }
        }
    }
    
    // MARK: - Subviews
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.2.circle")
                .font(.system(size: 60))
                .foregroundColor(.gray.opacity(0.5))
            
            Text("No Reservations Yet")
                .font(.title3)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
            
            Text(
                "When people reserve your event, they'll appear here"
            )
            .font(.subheadline)
            .foregroundColor(.secondary)
            .multilineTextAlignment(.center)
            .padding(.horizontal)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
    
    private var reservationsList: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                ForEach(reservedUserProfiles, id: \.self) {
                    userProfile in
                    ReservationUserCard(userProfile: userProfile)
                }
            }
            .padding(.horizontal)
        }
    }
}

// MARK: - Reservation User Card
struct ReservationUserCard: View {
    let userProfile: UserProfile
    
    var body: some View {
        HStack(spacing: 16) {
            // User Profile Image
            KFImage(URL(string: userProfile.profileImageUrl))
                .resizable()
                .scaledToFill()
                .frame(width: 60, height: 60)
                .clipShape(Circle())
                .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
            
            // User Info
            VStack(alignment: .leading, spacing: 4) {
                Text(userProfile.fullName)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                if !userProfile.bio.isEmpty {
                    Text(userProfile.bio)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                
                // Interests/Tags
                if !userProfile.interests.isEmpty {
                    HStack {
                        ForEach(userProfile.interests.prefix(3), id: \.self) {
                            interest in
                            Text(interest)
                                .font(.caption)
                                .foregroundColor(.goldenBrown)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(Color.goldenBrown.opacity(0.1))
                                .cornerRadius(4)
                        }
                    }
                }
            }
            
            Spacer()
            
            // Status Icon
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
                .font(.title3)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
    }
}
