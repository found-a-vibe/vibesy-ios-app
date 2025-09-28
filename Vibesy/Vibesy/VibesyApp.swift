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
                .onOpenURL { url in
                    handleIncomingURL(url)
                }
        }
    }
    
    // MARK: - URL Handling
    private func handleIncomingURL(_ url: URL) {
        print("📱 Received URL: \(url.absoluteString)")
        
        guard url.scheme == "vibesy" else {
            print("⚠️ Unrecognized URL scheme: \(url.scheme ?? "nil")")
            return
        }
        
        switch url.host {
        case "stripe":
            handleStripeURL(url)
        case "payment":
            handlePaymentURL(url)
        default:
            print("⚠️ Unrecognized URL host: \(url.host ?? "nil")")
        }
    }
    
    private func handleStripeURL(_ url: URL) {
        switch url.path {
        case "/onboard_complete":
            print("✅ Stripe Connect onboarding completed")
            // The HostOnboardingView will handle this via .onOpenURL
            
        default:
            print("⚠️ Unrecognized Stripe path: \(url.path)")
        }
    }
    
    private func handlePaymentURL(_ url: URL) {
        switch url.path {
        case "/complete":
            print("✅ Payment completed")
            // PaymentSheet will handle this automatically
            
        default:
            print("⚠️ Unrecognized payment path: \(url.path)")
        }
    }
}

extension View {
    func hideKeyboard() {
        let resign = #selector(UIResponder.resignFirstResponder)
        UIApplication.shared.sendAction(resign, to: nil, from: nil, for: nil)
    }
}
