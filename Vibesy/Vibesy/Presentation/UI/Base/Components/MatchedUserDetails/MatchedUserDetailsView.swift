//
//  MatchedUserDetailsView.swift
//  Vibesy
//
//  Created by Alexander Cleoni on 1/19/25.
//
import SwiftUI
import Kingfisher

struct MatchedUserDetailsView: View {
    @SwiftUI.Environment(\.dismiss) var dismiss
    
    @EnvironmentObject var userProfileModel: UserProfileModel
    @EnvironmentObject var eventModel: EventModel
    @EnvironmentObject var friendShipModel: FriendshipModel
    @EnvironmentObject var authenticationModel: AuthenticationModel
    
    @State private var friendRequestStatus = ""
    @State private var buttonStatusText = ""
    
    var navigate: ((_ direction: Direction) -> Void)? = nil
    
    var columns = [GridItem(.adaptive(minimum: 160), spacing: 20)]
    
    func getFriendButtonText() {
        switch (friendRequestStatus) {
        case "pending":
            buttonStatusText = "Cancel Request"
        default:
            buttonStatusText = "Add Friend"
        }
    }
    
    var body: some View {
        VStack {
            HStack {
                BackButtonView {
                    if let navigate = navigate {
                        navigate(.back)
                    } else {
                        dismiss()
                    }
                }
                
                Spacer()
                Text(userProfileModel.currentMatchedProfile.fullName.capitalized)
                    .font(.abeezeeItalic(size: 24))
                    .foregroundStyle(.espresso)
                    .padding(.trailing)
                Spacer()
            }
            // Profile details
            VStack(spacing: 16) {
                HStack(spacing: 16) {
                    // Profile image
                    VStack {
                        KFImage(URL(string: userProfileModel.currentMatchedProfile.profileImageUrl))
                            .resizable()
                            .scaledToFill()
                            .frame(width: 144, height: 144)
                            .clipped()
                            .cornerRadius(12)
                            .shadow(radius: 5)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    
                    VStack(alignment: .leading, spacing: 10) {
                        // Name and details
                        Text("Name: \(userProfileModel.currentMatchedProfile.fullName.capitalized)")
                            .font(.abeezeeItalic(size: 14))
                        Text("Age: \(userProfileModel.currentMatchedProfile.age)")
                            .font(.abeezeeItalic(size: 14))
                        Text("Pronouns: \(userProfileModel.currentMatchedProfile.pronouns)")
                            .font(.abeezeeItalic(size: 14))
                        if let uid = userProfileModel.currentMatchedProfile.uid {
                            if userProfileModel.userProfile.friends[uid] == nil {
                                Button(action: {
                                    if friendRequestStatus == "" {
                                        friendRequestStatus = "pending"
                                        if let fromUserId = authenticationModel.state.currentUser?.id, let toUserId = userProfileModel.currentMatchedProfile.uid {
                                            friendShipModel.sendFriendRequest(fromUserId: fromUserId, fromUserProfile: userProfileModel.userProfile, toUserId: toUserId, message: nil)
                                        }
                                    } else if friendRequestStatus == "pending" {
                                        friendRequestStatus = ""
                                        if let fromUserId = authenticationModel.state.currentUser?.id, let toUserId = userProfileModel.currentMatchedProfile.uid {
                                            friendShipModel.deleteFriendRequest(fromUserId: fromUserId, toUserId: toUserId)
                                        }
                                    }
                                    
                                    getFriendButtonText()
                                }) {
                                    Text(buttonStatusText)
                                        .font(.abeezeeItalic(size: 12))
                                        .foregroundColor(.white)
                                        .frame(maxWidth: 124, maxHeight: 28)
                                        .padding(2)
                                        .background(.sandstone)
                                        .cornerRadius(8)
                                }
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                
                // "My Vibe" section
                VStack(alignment: .leading, spacing: 8) {
                    Text("My Vibe")
                        .font(.abeezeeItalic(size: 16))
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text(userProfileModel.currentMatchedProfile.bio)
                        .font(.abeezeeItalic(size: 14))
                        .multilineTextAlignment(.leading)
                        .foregroundColor(.espresso)
                }
                .padding(.vertical)
                
                // Interests section
                VStack(alignment: .leading, spacing: 8) {
                    Text("Interests")
                        .font(.abeezeeItalic(size: 16))
                        .frame(maxWidth: .infinity, alignment: .leading)
                    HStack {
                        if !userProfileModel.currentMatchedProfile.interests.isEmpty {
                            ForEach(userProfileModel.currentMatchedProfile.interests, id: \.self) { interest in
                                ProfileTagView(text: interest)
                            }
                        }
                    }
                }
                .padding(.vertical)
                
                VStack {
                    Text("Liked Events")
                        .font(.abeezeeItalic(size: 16))
                        .frame(maxWidth: .infinity, alignment: .leading)
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: 10) {
                            ForEach(eventModel.likedEvents) { event in
                                EventCard(event: event, showIcon: false)
                            }
                        }
                    }
                }
            }
            Spacer()
        }
        .padding()
        .task {
            if let uid = userProfileModel.currentMatchedProfile.uid {
                await eventModel.getEventsByStatus(uid: uid, status: .likedEvents)
            }
        }
        .onAppear {
            let status = userProfileModel.currentMatchedProfile.friendRequests["status"] as? String
            if status != nil {
                self.friendRequestStatus = status ?? ""
            }
            getFriendButtonText()
        }
    }
}
