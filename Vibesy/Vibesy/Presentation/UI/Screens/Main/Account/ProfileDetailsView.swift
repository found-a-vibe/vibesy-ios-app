//
//  ProfileDetailsView.swift
//  Vibesy
//
//  Created by Alexander Cleoni on 12/18/24.
//

import SwiftUI
import Kingfisher
import WrappingHStack

struct ProfileDetailsView: View {
    @EnvironmentObject var authenticationModel: AuthenticationModel
    @EnvironmentObject var userProfileModel: UserProfileModel
    @EnvironmentObject var friendshipModel: FriendshipModel
    
    var navigate: ((_ direction: Direction) -> Void)? = nil
    
    var body: some View {
        VStack {
            HStack {
                BackButtonView {
                    if let navigate {
                        navigate(.back)
                    }
                }
                
                Spacer()
                Text(userProfileModel.userProfile.fullName.capitalized)
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
                        if userProfileModel.userProfile.profileImageUrl != "" {
                            KFImage(URL(string: userProfileModel.userProfile.profileImageUrl))
                                .resizable()
                                .scaledToFill()
                                .frame(width: 144, height: 144)
                                .clipped()
                                .cornerRadius(12)
                                .shadow(radius: 5)
                        } else {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(.sandstone.opacity(0.3))
                                .frame(width: 149, height: 144)
                                .overlay(alignment: .bottom) {
                                    Image(systemName: "person.fill")
                                        .resizable()
                                        .scaledToFit()
                                        .foregroundStyle(.sandstone)
                                        .frame(width: 114.5, height: 112)
                                }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    
                    
                    VStack(alignment: .leading, spacing: 10) {
                        // Name and details
                        Text("Name: \(userProfileModel.userProfile.fullName.capitalized)")
                            .font(.abeezeeItalic(size: 14))
                        Text("Age : \(userProfileModel.userProfile.age)")
                            .font(.abeezeeItalic(size: 14))
                        Text("Pronouns: \(userProfileModel.userProfile.pronouns)")
                            .font(.abeezeeItalic(size: 14))
                        
                        Button(action: {
                            // Edit Profile action
                            if let navigate {
                                navigate(.forward)
                            }
                        }) {
                            Text("Edit Profile")
                                .font(.abeezeeItalic(size: 12))
                                .foregroundColor(.white)
                                .frame(maxWidth: 124, maxHeight: 28)
                                .padding(2)
                                .background(.sandstone)
                                .cornerRadius(8)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                
                // "My Vibe" section
                VStack(alignment: .leading, spacing: 8) {
                    Text("My Vibe")
                        .font(.abeezeeItalic(size: 16))
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text(userProfileModel.userProfile.bio)
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
                    WrappingHStack(userProfileModel.userProfile.interests) { interest in
                        ProfileTagView(text: interest)
                            .padding(.vertical, 8)
                    }
                }
                .padding(.vertical)
            }
            Spacer()
        }
        .padding()
    }
}

// Reusable tag view
struct ProfileTagView: View {
    var text: String
    
    var body: some View {
        Text("#\(text)")
            .font(.abeezeeItalic(size: 12))
            .foregroundColor(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.goldenBrown)
            .cornerRadius(12)
    }
}

#Preview {
    let userProfileModel = UserProfileModel.mockUserProfileModel
    
    ProfileDetailsView()
        .environmentObject(userProfileModel)
}
