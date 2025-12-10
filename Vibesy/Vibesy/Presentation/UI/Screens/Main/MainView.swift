//
//  MainView.swift
//  Vibesy
//
//  Created by Alexander Cleoni on 12/14/24.
//

import Combine
import SwiftUI
import StreamChatSwiftUI
import os.log

// MARK: - Tab Item Configuration
struct TabItemConfig {
    let imageName: String
    let title: String
    let accessibilityLabel: String
    let accessibilityHint: String
}

// MARK: - Main View
struct MainView: View {
    private static let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "Vibesy", category: "MainView")
    
    // MARK: - Environment
    @SwiftUI.Environment(\.scenePhase) private var scenePhase
    @SwiftUI.Environment(\.accessibilityReduceMotion) private var reduceMotion
    @SwiftUI.Environment(\.accessibilityDifferentiateWithoutColor) private var differentiateWithoutColor
    @SwiftUI.Environment(\.colorScheme) private var colorScheme
    
    // MARK: - Environment Objects
    @EnvironmentObject var authenticationModel: AuthenticationModel
    @EnvironmentObject var userProfileModel: UserProfileModel
    @EnvironmentObject var eventModel: EventModel
    @EnvironmentObject var friendshipModel: FriendshipModel
    @EnvironmentObject private var tabBarVisibilityModel: TabBarVisibilityModel
    
    // MARK: - State
    @State private var selectedTab = 0
    @State private var isNewEventViewPresented: Bool = false
    @State private var showErrorAlert = false
    @State private var errorMessage = ""
    @State private var isAppearingForFirstTime = true
    
    // MARK: - Tab Configuration
    private let tabConfigs: [TabItemConfig] = [
        TabItemConfig(
            imageName: "Home",
            title: "Explore",
            accessibilityLabel: "Explore events",
            accessibilityHint: "Browse and discover events in your area"
        ),
        TabItemConfig(
            imageName: "Messenger",
            title: "Chat",
            accessibilityLabel: "Messages",
            accessibilityHint: "View your conversations and chat with other users"
        ),
        TabItemConfig(
            imageName: "Plus",
            title: "Create",
            accessibilityLabel: "Create event",
            accessibilityHint: "Create a new event"
        ),
        TabItemConfig(
            imageName: "Heart",
            title: "Liked",
            accessibilityLabel: "Liked events",
            accessibilityHint: "View events you have liked"
        ),
        TabItemConfig(
            imageName: "Account",
            title: "Account",
            accessibilityLabel: "Account settings",
            accessibilityHint: "Manage your profile and account settings"
        )
    ]
    
    // MARK: - Initialization
    init() {
        setupTabBarAppearance()
        Self.logger.info("MainView initialized")
    }
    
    // MARK: - Private Methods
    private func setupTabBarAppearance() {
        let appearance = UITabBarAppearance()
        
        // Configure background
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(Color(.goldenBrown))
        appearance.shadowColor = UIColor.black.withAlphaComponent(0.1)
        
        // Configure normal state
        appearance.stackedLayoutAppearance.normal.iconColor = UIColor.white
        appearance.stackedLayoutAppearance.normal.titleTextAttributes = [
            .foregroundColor: UIColor.white,
            .font: UIFont.systemFont(ofSize: 12, weight: .medium)
        ]
        
        // Configure selected state  
        appearance.stackedLayoutAppearance.selected.iconColor = UIColor(Color(.goldenBrown))
        appearance.stackedLayoutAppearance.selected.titleTextAttributes = [
            .foregroundColor: UIColor(Color(.goldenBrown)),
            .font: UIFont.systemFont(ofSize: 12, weight: .semibold)
        ]
        
        // Also configure compact and inline layouts for consistency
        appearance.compactInlineLayoutAppearance.normal.iconColor = UIColor.white
        appearance.compactInlineLayoutAppearance.normal.titleTextAttributes = [
            .foregroundColor: UIColor.white,
            .font: UIFont.systemFont(ofSize: 12, weight: .medium)
        ]
        appearance.compactInlineLayoutAppearance.selected.iconColor = UIColor(Color(.goldenBrown))
        appearance.compactInlineLayoutAppearance.selected.titleTextAttributes = [
            .foregroundColor: UIColor(Color(.goldenBrown)),
            .font: UIFont.systemFont(ofSize: 12, weight: .semibold)
        ]
        
        appearance.inlineLayoutAppearance.normal.iconColor = UIColor.white
        appearance.inlineLayoutAppearance.normal.titleTextAttributes = [
            .foregroundColor: UIColor.white,
            .font: UIFont.systemFont(ofSize: 12, weight: .medium)
        ]
        appearance.inlineLayoutAppearance.selected.iconColor = UIColor(Color(.goldenBrown))
        appearance.inlineLayoutAppearance.selected.titleTextAttributes = [
            .foregroundColor: UIColor(Color(.goldenBrown)),
            .font: UIFont.systemFont(ofSize: 12, weight: .semibold)
        ]
        
        // Apply to tab bar with iOS 16+ compatible method
        if #available(iOS 15.0, *) {
            UITabBar.appearance().standardAppearance = appearance
            UITabBar.appearance().scrollEdgeAppearance = appearance
        }
        
        // For iOS 16+, also set the appearance directly when the view appears
        DispatchQueue.main.async {
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let window = windowScene.windows.first {
                if let tabBarController = window.rootViewController as? UITabBarController {
                    tabBarController.tabBar.standardAppearance = appearance
                    tabBarController.tabBar.scrollEdgeAppearance = appearance
                }
            }
        }
    }
    
    private func applyTabBarAppearance() {
        // Create the appearance configuration
        let appearance = UITabBarAppearance()
        
        // Configure background
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(Color(.goldenBrown))
        appearance.shadowColor = UIColor.black.withAlphaComponent(0.1)
        
        // Configure normal state
        appearance.stackedLayoutAppearance.normal.iconColor = UIColor.white
        appearance.stackedLayoutAppearance.normal.titleTextAttributes = [
            .foregroundColor: UIColor.white,
            .font: UIFont.systemFont(ofSize: 12, weight: .medium)
        ]
        
        // Configure selected state  
        appearance.stackedLayoutAppearance.selected.iconColor = UIColor(Color(.goldenBrown))
        appearance.stackedLayoutAppearance.selected.titleTextAttributes = [
            .foregroundColor: UIColor(Color(.goldenBrown)),
            .font: UIFont.systemFont(ofSize: 12, weight: .semibold)
        ]
        
        // Also configure compact and inline layouts for consistency
        appearance.compactInlineLayoutAppearance.normal.iconColor = UIColor.white
        appearance.compactInlineLayoutAppearance.normal.titleTextAttributes = [
            .foregroundColor: UIColor.white,
            .font: UIFont.systemFont(ofSize: 12, weight: .medium)
        ]
        appearance.compactInlineLayoutAppearance.selected.iconColor = UIColor(Color(.goldenBrown))
        appearance.compactInlineLayoutAppearance.selected.titleTextAttributes = [
            .foregroundColor: UIColor(Color(.goldenBrown)),
            .font: UIFont.systemFont(ofSize: 12, weight: .semibold)
        ]
        
        appearance.inlineLayoutAppearance.normal.iconColor = UIColor.white
        appearance.inlineLayoutAppearance.normal.titleTextAttributes = [
            .foregroundColor: UIColor.white,
            .font: UIFont.systemFont(ofSize: 12, weight: .medium)
        ]
        appearance.inlineLayoutAppearance.selected.iconColor = UIColor(Color(.goldenBrown))
        appearance.inlineLayoutAppearance.selected.titleTextAttributes = [
            .foregroundColor: UIColor(Color(.goldenBrown)),
            .font: UIFont.systemFont(ofSize: 12, weight: .semibold)
        ]
        
        // Apply the appearance to the current tab bar controller
        DispatchQueue.main.async {
            if let windowScene = UIApplication.shared.connectedScenes.first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene,
               let window = windowScene.windows.first(where: { $0.isKeyWindow }) {
                
                // Find the tab bar controller in the view hierarchy
                var currentViewController = window.rootViewController
                while let presentedViewController = currentViewController?.presentedViewController {
                    currentViewController = presentedViewController
                }
                
                if let tabBarController = currentViewController as? UITabBarController {
                    tabBarController.tabBar.standardAppearance = appearance
                    tabBarController.tabBar.scrollEdgeAppearance = appearance
                    
                    // Force update
                    if #available(iOS 15.0, *) {
                        tabBarController.tabBar.setNeedsLayout()
                    }
                }
            }
        }
    }
    
    private func checkNotificationChannel() {
        Task { @MainActor in
            if VibesyNotificationCenter.shared.notificationChannelId != nil {
                selectedTab = 1
                Self.logger.debug("Navigated to chat due to notification")
            }
        }
    }
    
    private func handleNewEventTab() {
        guard selectedTab == 2 else { return }
        
        selectedTab = 0 // Reset to explore tab
        
        // Add haptic feedback for better UX
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
        
        isNewEventViewPresented = true
        Self.logger.debug("New event view presented")
    }
    
    private func handleEventCountChange(oldValue: Int, newValue: Int) {
        if newValue > oldValue {
            isNewEventViewPresented = false
            
            // Show success feedback
            let notificationFeedback = UINotificationFeedbackGenerator()
            notificationFeedback.notificationOccurred(.success)
            
            Self.logger.info("Event created successfully, dismissing new event view")
        }
    }
    
    private func handleScenePhaseChange(_ newPhase: ScenePhase) {
        switch newPhase {
        case .active:
            if !isAppearingForFirstTime {
                checkNotificationChannel()
            }
            isAppearingForFirstTime = false
            Self.logger.debug("App became active")
            
        case .inactive:
            Self.logger.debug("App became inactive")
            
        case .background:
            Self.logger.debug("App entered background")
            
        @unknown default:
            Self.logger.warning("Unknown scene phase: \(String(describing: newPhase))")
        }
    }
    
    private func showError(_ message: String) {
        errorMessage = message
        showErrorAlert = true
        Self.logger.error("Showing error: \(message)")
    }
    // MARK: - Body
    var body: some View {
        ZStack(alignment: .bottom) {
            TabView(selection: $selectedTab) {
                // Explore Tab
                ExploreViewCoordinator()
                    .tabItem {
                        tabItemView(for: 0)
                    }
                    .tag(0)
                
                // Chat Tab
                ChatViewCoordinator()
                    .tabItem {
                        tabItemView(for: 1)
                    }
                    .tag(1)
                
                // Create Event Tab (Placeholder)
                NewEventViewCoordinator()
                    .tabItem {
                        tabItemView(for: 2)
                    }
                    .tag(2)
                
                // Liked Events Tab
                LikedEventsViewCoordinator()
                    .tabItem {
                        tabItemView(for: 3)
                    }
                    .tag(3)
                
                // Account Tab
                AccountViewCoordinator()
                    .tabItem {
                        tabItemView(for: 4)
                    }
                    .tag(4)
            }
            .tint(.goldenBrown)
            .onAppear {
                applyTabBarAppearance()
            }
            .onChange(of: selectedTab) { oldTab, newTab in
                handleNewEventTab()
            }
            
            // Custom Tab Indicator
            if tabBarVisibilityModel.isTabBarVisible {
                VStack {
                    Spacer()
                    TabIndicator(
                        selectedTab: $selectedTab,
                        reduceMotion: reduceMotion,
                        differentiateWithoutColor: differentiateWithoutColor
                    )
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
                    .accessibilityAddTraits(.isModal)
                    .accessibilityLabel("Create new event")
            }
        }
        .alert("Error", isPresented: $showErrorAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
        .onChange(of: eventModel.events.count) { oldValue, newValue in
            handleEventCountChange(oldValue: oldValue, newValue: newValue)
        }
        .onChange(of: scenePhase) {_, newPhase in
            handleScenePhaseChange(newPhase)
        }
        .onChange(of: eventModel.errorMessage) {_, newError in
            if let error = newError {
                showError(error)
            }
        }
        .onAppear {
            Self.logger.debug("MainView appeared")
            applyTabBarAppearance()
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Main navigation")
    }
    
    // MARK: - Helper Views
    @ViewBuilder
    private func tabItemView(for index: Int) -> some View {
        if index >= tabConfigs.count {
            EmptyView()
        } else {
            let config = tabConfigs[index]
            VStack {
                Image(config.imageName)
                    .renderingMode(.template)
                    .accessibilityHidden(true)
                
                if !differentiateWithoutColor || selectedTab == index {
                    Text(config.title)
                        .font(.caption2)
                        .accessibilityHidden(true)
                }
            }
            .accessibilityLabel(config.accessibilityLabel)
            .accessibilityHint(config.accessibilityHint)
            .accessibilityAddTraits(selectedTab == index ? .isSelected : [])
        }
    }
}

// MARK: - Tab Indicator
struct TabIndicator: View {
    @Binding var selectedTab: Int
    let reduceMotion: Bool
    let differentiateWithoutColor: Bool
    
    private let indicatorWidth: CGFloat = 36
    private let tabCount: CGFloat = 5
    
    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width / tabCount
            let offset = (CGFloat(selectedTab) * width) + (width - indicatorWidth) / 2
            
            Rectangle()
                .fill(indicatorColor)
                .frame(width: indicatorWidth, height: 4)
                .offset(x: offset, y: 0)
                .animation(
                    reduceMotion ? .none : .easeInOut(duration: 0.3),
                    value: selectedTab
                )
                .accessibilityHidden(true) // Hidden since tab items already provide accessibility
        }
        .frame(height: 4)
        .clipped()
    }
    
    private var indicatorColor: Color {
        if differentiateWithoutColor {
            return Color.primary
        } else {
            return Color(.goldenBrown)
        }
    }
}

// MARK: - Preview
#Preview {
    MainView()
        .environmentObject(AuthenticationModel(authenticationService: MockAuthenticationService(), state: AppState()))
        .environmentObject(UserProfileModel.mockUserProfileModel)
        .environmentObject(EventModel(service: MockEventService()))
        .environmentObject(FriendshipModel(service: MockFriendshipService(), friendRequests: []))
        .environmentObject(TabBarVisibilityModel())
}

// MARK: - Mock Services for Preview
struct MockAuthenticationService: AuthenticationService {
    func signUp(email: String, password: String) -> Future<AuthUser?, Error> {
        Future { promise in
            // Mock success case
            promise(.success(nil))
            // Or mock failure case:
            // promise(.failure(AuthError.invalidCredentials))
        }
    }
    
    func signIn(email: String, password: String) -> Future<AuthUser?, Error> {
        Future { promise in
            // Mock successful sign in with a user
            let mockUser = AuthUser(id: "mock-id", email: email, isNewUser: false)
            promise(.success(mockUser))
        }
    }
    
    func signOut() -> Future<Void, Never> {
        Future { promise in
            promise(.success(()))
        }
    }
    
    func updateCurrentUserPassword(email: String, password: String, newPassword: String) -> Future<Void, Error> {
        Future { promise in
            promise(.success(()))
        }
    }
    
    func deleteCurrentUser(email: String, password: String) -> Future<Void, Error> {
        Future { promise in
            promise(.success(()))
        }
    }
}

struct MockEventService: EventService {
    func getEventFeed(uid: String) async throws -> [Event] { [] }
    func createOrUpdateEvent(_ event: Event, guestImages: [UUID: UIImage]) async throws -> Event { event }
    func deleteEvent(eventId: String, createdByUid: String) async throws {}
    func getEventsByStatus(uid: String, status: EventStatus) async throws -> [Event] { [] }
    func likeEvent(eventId: String, userID: String) async throws {}
    func unlikeEvent(eventId: String, userID: String) async throws {}
}

struct MockFriendshipService: FriendshipService {
    func sendFriendRequest(fromUserId: String, fromUserProfile: UserProfile, toUserId: String, message: String?, completion: @escaping (Error?) -> Void) {
        // Mock successful send
        completion(nil)
    }
    
    func acceptFriendRequest(fromUserId: String, toUserId: String, completion: @escaping (Error?) -> Void) {
        // Mock successful accept
        completion(nil)
    }
    
    func deleteFriendRequest(fromUserId: String, toUserId: String, completion: @escaping (Error?) -> Void) {
        // Mock successful delete
        completion(nil)
    }
    
    func fetchPendingFriendRequests(userId: String, status: String, completion: @escaping ([FriendRequest]?, Error?) -> Void) {
        // Mock empty friend requests
        completion([], nil)
    }
    
    func fetchFriendList(userId: String, completion: @escaping ([String]?, Error?) -> Void) {
        // Mock empty friend list
        completion([], nil)
    }
}
