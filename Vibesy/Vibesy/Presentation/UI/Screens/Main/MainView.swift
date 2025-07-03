//
//  MainView.swift
//  Vibesy
//
//  Created by Alexander Cleoni on 12/14/24.
//

import SwiftUI
import StreamChatSwiftUI

struct MainView: View {
    @SwiftUI.Environment(\.scenePhase) private var scenePhase
    
    @EnvironmentObject var authenticationModel: AuthenticationModel
    @EnvironmentObject var userProfileModel: UserProfileModel
    @EnvironmentObject var eventModel: EventModel
    @EnvironmentObject var friendshipModel: FriendshipModel
    @EnvironmentObject private var tabBarVisibilityModel: TabBarVisibilityModel

    
    @State private var selectedTab = 0
    @State private var isFullScreenPresented: Bool = false
    
    @StateObject private var chatModel: ChatModel = ChatModel()
    
    @State private var isNewEventViewPresented: Bool = false
    
    init() {
        let appearance = UITabBarAppearance()
        
        // Customize unselected tab item appearance (white color for unselected items)
        appearance.stackedLayoutAppearance.normal.iconColor = UIColor.white
        appearance.stackedLayoutAppearance.normal.titleTextAttributes = [NSAttributedString.Key.foregroundColor: UIColor.white]
        
        // Customize selected tab item appearance (pink color for selected items)
        appearance.stackedLayoutAppearance.selected.iconColor = UIColor(Color(.espresso))
        appearance.stackedLayoutAppearance.selected.titleTextAttributes = [NSAttributedString.Key.foregroundColor: UIColor(Color(.espresso))]
        
        // Set background color of the tab bar to blue
        appearance.backgroundColor = UIColor(Color(.sandstone))
        
        // Apply these changes to the tab bar appearance
        UITabBar.appearance().standardAppearance = appearance
        if #available(iOS 15.0, *) {
            UITabBar.appearance().scrollEdgeAppearance = appearance
        }
    }
    
    private func checkNotificationChannel() {
        if VibesyNotificationCenter.shared.notificationChannelId != nil {
            selectedTab = 1
        }
    }
    
    var body: some View {
        ZStack(alignment: .bottom) {
            TabView(selection: $selectedTab) {
                ExploreViewCoordinator()
                    .tabItem {
                        Image("Home")
                            .renderingMode(.template)
                    }
                    .tag(0)
                ChatViewCoordinator()
                    .tabItem {
                        Image("Messenger")
                            .renderingMode(.template)
                    }
                    .tag(1)
                NewEventViewCoordinator()
                    .tabItem {
                        Image("Plus")
                            .renderingMode(.template)
                    }
                    .onChange(of: selectedTab) { oldTab, newTab in
                        if newTab == 2 {
                            selectedTab = 0 // Reset to a different tab after showing the full-screen cover
                            isNewEventViewPresented = true
                        }
                    }
                    .tag(2)
                
                LikedEventsViewCoordinator()
                    .tabItem {
                        Image("Heart")
                            .renderingMode(.template)
                    }
                    .tag(3)
                
                AccountViewCoordinator()
                    .tabItem {
                        Image("Account")
                            .renderingMode(.template)
                    }
                    .tag(4)
            }
            .tint(.sandstone)
            // Overlay TabIndicator at the bottom of the screen
            if tabBarVisibilityModel.isTabBarVisible {
                VStack {
                    Spacer()
                    TabIndicator(selectedTab: $selectedTab)
                        .frame(height: 4)
                        .padding(.bottom, 45)
                }
                .ignoresSafeArea(.keyboard, edges: .bottom)
            }
        }
        .background(
            TabBarVisibilityCoordinator(isTabBarVisible: $tabBarVisibilityModel.isTabBarVisible)
        )
        .fullScreenCover(isPresented: $isNewEventViewPresented) {
            NavigationStack {
                NewEventView0(isNewEventViewPresented: $isNewEventViewPresented)
            }
        }
        .onChange(of: eventModel.events.count) { oldValue, newValue in
            if newValue > oldValue {
                isNewEventViewPresented = false
            }
        }
        .onChange(of: userProfileModel.userProfile) { oldValue, newValue in
            if let currentUser = authenticationModel.state.currentUser {
                if let profileImageUrl = URL(string: userProfileModel.userProfile.profileImageUrl) {
                    chatModel.connectUser(userId: currentUser.id, name: userProfileModel.userProfile.fullName, imageURL: profileImageUrl)
                } else {
                    chatModel.connectUser(userId: currentUser.id, name: userProfileModel.userProfile.fullName, imageURL: nil)
                }
            }
        }
        .onChange(of: scenePhase) {_, newPhase in
            if newPhase == .active {
                checkNotificationChannel()
            }
        }
    }
}

struct TabIndicator: View {
    @Binding var selectedTab: Int
    private let indicatorWidth: CGFloat = 36
    
    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width / 5
            let offset = (CGFloat(selectedTab) * width) + (width - indicatorWidth) / 2
            
            Rectangle()
                .fill(Color(.espresso))
                .frame(width: indicatorWidth, height: 4)
                .offset(x: offset, y: 0)
                .animation(.easeInOut(duration: 0.3), value: selectedTab)
        }
        .frame(height: 4)
        
    }
}

#Preview {
    MainView()
}
