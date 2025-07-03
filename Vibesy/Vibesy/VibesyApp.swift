//
//  VibesyApp.swift
//  Vibesy
//
//  Created by Alexander Cleoni on 11/21/24.
//

import SwiftUI
import SwiftData

@main
struct VibesyApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    @StateObject var authenticationModel = AuthenticationModel(authenticationService: FirebaseAuthenticationService(), state: AppState())
    @StateObject var userProfileModel = UserProfileModel(userProfileService: FirebaseUserProfileService())
    @StateObject var eventModel = EventModel(service: FirebaseEventService())
    @StateObject var interactionModel = InteractionModel(service: FirebaseInteractionService())
    @StateObject var friendshipModel = FriendshipModel(service: FirebaseFriendshipService(), friendRequests: [])
    @StateObject var tabBarVisibilityModel = TabBarVisibilityModel()
    @StateObject var userPasswordModel = UserPasswordModel(service: VibesyUserPasswordService())


    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(authenticationModel)
                .environmentObject(userProfileModel)
                .environmentObject(eventModel)
                .environmentObject(interactionModel)
                .environmentObject(friendshipModel)
                .environmentObject(tabBarVisibilityModel)
                .environmentObject(userPasswordModel)
        }
    }
}

extension View {
    func hideKeyboard() {
        let resign = #selector(UIResponder.resignFirstResponder)
        UIApplication.shared.sendAction(resign, to: nil, from: nil, for: nil)
    }
}
