//
//  NotificationView.swift
//  Vibesy
//
//  Created by Alexander Cleoni on 2/23/25.
//

import SwiftUI
import Kingfisher


struct Notification: Identifiable {
    let id = UUID()
    let title: String
    let message: String
    let timestamp: String
}

struct NotificationHeaderView: View {
    @EnvironmentObject var explorePageCoordinator: ExplorePageCoordinator

    var body: some View {
        HStack {
            BackButtonView {
                explorePageCoordinator.pop()
            }
            
            Text("Notifications")
                .foregroundStyle(.espresso)
                .font(.abeezeeItalic(size: 26))
                .frame(maxWidth: .infinity, alignment: .center)
        }
        .padding(.horizontal)
    }
}

struct NotificationView: View {
    @ObservedObject var notificationCenter: VibesyNotificationCenter = .shared

    @EnvironmentObject var authenticationModel: AuthenticationModel
    @EnvironmentObject var friendshipModel: FriendshipModel
    
    func convertToString(date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM d, yyyy 'at' h:mm:ss a z" // Desired format
        formatter.timeZone = TimeZone.current
        
        let formattedString = formatter.string(from: date)
        return formattedString
        
    }
    
    var body: some View {
        VStack {
            NotificationHeaderView()
            ScrollView {
                ForEach($friendshipModel.friendRequests, id: \.self) { $request in
                    if let request {
                        HStack(spacing: 12) {
                            if let urlString = request.senderImageURL, let url = URL(string: urlString) {
                                KFImage(url)
                                    .resizable()
                                    .frame(width: 60, height: 60)
                                    .clipShape(Circle())
                            } else {
                                Circle()
                                    .fill(Color.gray.opacity(0.2))
                                    .overlay(
                                        Image(systemName: "person.fill")
                                            .foregroundStyle(.gray)
                                    )
                                    .frame(width: 60, height: 60)
                            }
                            VStack(alignment: .leading, spacing: 5) {
                                Text(request.senderName)
                                    .font(.headline)
                                    .foregroundColor(.espresso)
                                
                                Text("sent you a friend request")
                                    .font(.subheadline)
                                    .foregroundColor(.gray)
                                
                                HStack {
                                    Button(action: {
                                        // Edit Profile action
                                        if let id = authenticationModel.state.currentUser?.id {
                                            friendshipModel.acceptFriendRequest(fromUserId: request.senderUID, toUserId: id)
                                        }
                                    }) {
                                        Text("Accept")
                                            .font(.abeezeeItalic(size: 12))
                                            .foregroundColor(.white)
                                            .frame(width: 124, height: 28)
                                            .padding(2)
                                            .background(.espresso)
                                            .cornerRadius(8)
                                    }
                                    
                                    Button(action: {
                                        // Edit Profile action
                                        if let id = authenticationModel.state.currentUser?.id {
                                            friendshipModel.deleteFriendRequest(fromUserId: request.senderUID, toUserId: id)
                                        }
                                        
                                    }) {
                                        Text("Ignore")
                                            .font(.abeezeeItalic(size: 12))
                                            .foregroundColor(.espresso)
                                            .frame(width: 124, height: 28)
                                            .padding(2)
                                            .background(.white)
                                            .border(.espresso, width: 1)
                                            .cornerRadius(8)
                                    }
                                    
                                }
                            }
                        }
                        Divider()
                    }
                    
                }
            }
            .padding()
        }
        .onAppear {
            if let _ = notificationCenter.navigateToPushNotifications {
                notificationCenter.navigateToPushNotifications = false
            }
            if let currentUser = authenticationModel.state.currentUser {
                friendshipModel.fetchPendingFriendRequests(userId: currentUser.id, status: "pending")
            }
        }
    }
    
    // Function to calculate "time ago" from a timestamp string
    func timeAgo(from timestamp: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM d, yyyy 'at' h:mm:ss a 'UTC'X" // Corrected date format
        formatter.locale = Locale(identifier: "en_US_POSIX") // Ensure consistency in parsing
        formatter.timeZone = TimeZone(abbreviation: "UTC") // Set to UTC

        guard let date = formatter.date(from: timestamp) else {
            return "Invalid date"
        }

        let now = Date()
        let diff = Int(now.timeIntervalSince(date))

        if diff < 60 {
            return "\(diff) sec ago"
        } else if diff < 3600 {
            return "\(diff / 60) min ago"
        } else if diff < 86400 {
            return "\(diff / 3600) hours ago"
        } else if diff < 604800 {
            return "\(diff / 86400) days ago"
        } else if diff < 2419200 {
            return "\(diff / 604800) weeks ago"
        } else {
            return "\(diff / 2419200) months ago"
        }
    }
}


#Preview {
    NotificationView()
}
