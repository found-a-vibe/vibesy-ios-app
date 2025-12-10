//
//  ExploreView.swift
//  FoundAVibe
//
//  Created by Alexander Cleoni on 10/20/24.
//

import SwiftUI
import Kingfisher

struct ExploreHeaderView: View {
    @EnvironmentObject var explorePageCoordinator: ExplorePageCoordinator

    var headerImageUrl: String?
    
    var body: some View {
        HStack {
            if let url = headerImageUrl, url != "" {
                KFImage(URL(string: url))
                    .resizable()
                    .scaledToFill()
                    .clipShape(Circle())
                    .shadow(radius: 5)
                    .frame(width: 48, height: 48)
                    .onTapGesture {
                        explorePageCoordinator.push(page: .profileDetails)
                    }
            } else {
                Image(uiImage: UIImage(systemName: "person.circle")!)
                    .resizable()
                    .scaledToFill()
                    .clipShape(Circle())
                    .shadow(radius: 5)
                    .frame(width: 48, height: 48)
                    .onTapGesture {
                        explorePageCoordinator.push(page: .profileDetails)
                    }
            }
            Spacer()
            Text("Explore")
                .foregroundStyle(.goldenBrown)
                .font(.aBeeZeeRegular(size: 26))
            Spacer()
            RoundedRectangle(cornerRadius: 10)
                .overlay(alignment: .center) {
                    Image("Bell")
                        .renderingMode(.template)
                        .resizable()
                        .frame(width: 28, height: 28)
                }
                .frame(maxWidth: 38, maxHeight: 35)
                .foregroundStyle(.white)
                .onTapGesture {
                    explorePageCoordinator.push(page: .notificationView)
                }
            
        }
        .padding(.horizontal)
    }
}

struct ExploreView: View {
    @SwiftUI.Environment(\.scenePhase) private var scenePhase

    @EnvironmentObject var explorePageCoordinator: ExplorePageCoordinator
    
    @EnvironmentObject var authenticationModel: AuthenticationModel
    @EnvironmentObject var eventModel: EventModel
    @EnvironmentObject var userProfileModel: UserProfileModel
    @EnvironmentObject var friendshipModel: FriendshipModel
    
    @ObservedObject var notificationCenter: VibesyNotificationCenter = .shared
    
    var body: some View {
        VStack {
            ExploreHeaderView(headerImageUrl: userProfileModel.userProfile.profileImageUrl)
            ZStack {
                CardStackView()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .onChange(of: scenePhase) {_, newPhase in
            if newPhase == .active {
                if notificationCenter.navigateToPushNotifications != nil {
                    explorePageCoordinator.push(page: .notificationView)
                }
            }
        }
    }
}

#Preview {
    ExploreView()
}
