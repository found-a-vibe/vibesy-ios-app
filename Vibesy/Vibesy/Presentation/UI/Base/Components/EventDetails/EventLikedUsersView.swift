//
//  EventLikedUsersView.swift
//  Vibesy
//
//  Created by Alexander Cleoni on 3/6/25.
//

import Kingfisher
import SwiftUI

struct EventLikedUsersView: View {
    @Binding var users: [UserProfile]
    @State private var maxUsersToShow = 3
    
    var navigate: ((_ direction: Direction) -> Void)? = nil
    
    var body: some View {
        VStack(alignment: .center) {
            HStack {
                Text("Matched Profiles")
                    .font(.aBeeZeeRegular(size: 16))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if users.count > maxUsersToShow {
                    Button(action: {
                        // TODO
                    }) {
                        Text("View All")
                            .font(.aBeeZeeRegular(size: 16))
                            .foregroundColor(.goldenBrown)
                            .padding(.vertical, 10)
                            .padding(.horizontal, 20)
                    }
                    .frame(maxWidth: .infinity, alignment: .trailing)
                }
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(users.prefix(maxUsersToShow), id: \.self) { user in
                        EventUserCardView(user: user) { direction in
                            if let navigate {
                                navigate(direction)
                            }
                        }
                    }
                }
                .padding(.vertical)
                .padding(.horizontal, 4)
            }
        }
        .padding()
    }
}

struct EventUserCardView: View {
    @EnvironmentObject var userProfileModel: UserProfileModel
    
    let user: UserProfile
    var navigate: ((_ direction: Direction) -> Void)? = nil
    
    var body: some View {
        VStack(spacing: 8) {
            ZStack(alignment: .topTrailing) {
                KFImage(URL(string: user.profileImageUrl))
                    .resizable()
                    .scaledToFill()
                    .frame(width: 80, height: 80)
                    .clipShape(Circle())
                    .shadow(radius: 3)
            }
            Text(user.fullName)
                .font(.aBeeZeeRegular(size: 12))
            Button(action: {
                userProfileModel.currentMatchedProfile = user
                if let navigate = navigate {
                    navigate(.forward)
                }
            }) {
                Text("Profile")
                    .font(.footnote)
                    .foregroundColor(.white)
                    .padding(.vertical, 6)
                    .padding(.horizontal, 20)
                    .background(.goldenBrown)
                    .cornerRadius(8)
            }
        }
        .frame(maxWidth: 111, maxHeight: 129)
        .padding()
        .background(Color.white)
        .cornerRadius(5)
        .shadow(radius: 4)
    }
}
