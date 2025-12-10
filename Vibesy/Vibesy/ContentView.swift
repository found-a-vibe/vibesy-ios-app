//
//  ContentView.swift
//  Vibesy
//
//  Created by Alexander Cleoni on 11/21/24.
//

import SwiftUI

enum Screen {
    case home
    case main
}

struct ContentView: View {
    @EnvironmentObject var authenticationModel: AuthenticationModel
    @EnvironmentObject var userProfileModel: UserProfileModel
    @EnvironmentObject var eventModel: EventModel
    
    @ObservedObject var notificationCenter: VibesyNotificationCenter = .shared
    
    @State private var currentScreen: Screen = .home
    
    var body: some View {
        ZStack {
            switch currentScreen {
            case .home:
                HomeViewCoordinator()
            case .main:
                MainView()
                    .task {
                        if let user = authenticationModel.state.currentUser {
                            userProfileModel.getUserProfile(userId: user.id) { status in
                                if status == "success" {
                                    authenticationModel.connectUser(username: userProfileModel.userProfile.fullName, photoUrl: userProfileModel.userProfile.profileImageUrl)
                                }
                            }
                            await eventModel.fetchEventFeed(uid: user.id)
                            notificationCenter.registerForPushNotifications()
                        }
                    }
            }
        }
        .onChange(of: authenticationModel.state.currentUser) {currentUser, updatedUser in
                    if let user = updatedUser {
                        if !user.isNewUser {
                            currentScreen = .main
                        }
                    } else {
                        currentScreen = .home
                    }
                }
    }
}

#Preview {
    ContentView()
}
