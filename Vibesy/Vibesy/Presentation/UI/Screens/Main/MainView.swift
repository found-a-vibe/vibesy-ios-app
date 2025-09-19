//
//  MainView.swift
//  Vibesy
//
//  Created by Alexander Cleoni on 12/14/24.
//

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
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityDifferentiateWithoutColor) private var differentiateWithoutColor
    @Environment(\.colorScheme) private var colorScheme
    
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
        
        // Configure normal state
        appearance.stackedLayoutAppearance.normal.iconColor = UIColor.white
        appearance.stackedLayoutAppearance.normal.titleTextAttributes = [
            .foregroundColor: UIColor.white,
            .font: UIFont.systemFont(ofSize: 12, weight: .medium)
        ]
        
        // Configure selected state
        appearance.stackedLayoutAppearance.selected.iconColor = UIColor(Color(.espresso))
        appearance.stackedLayoutAppearance.selected.titleTextAttributes = [
            .foregroundColor: UIColor(Color(.espresso)),
            .font: UIFont.systemFont(ofSize: 12, weight: .semibold)
        ]
        
        // Set background
        appearance.backgroundColor = UIColor(Color(.sandstone))
        appearance.shadowColor = UIColor.black.withAlphaComponent(0.1)
        
        // Apply to tab bar
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
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
            Self.logger.warning("Unknown scene phase: \(newPhase)")
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
            .tint(.sandstone)
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
        .onChange(of: eventModel.events.count, handleEventCountChange)
        .onChange(of: scenePhase, handleScenePhaseChange)
        .onChange(of: eventModel.errorMessage) { _, newError in
            if let error = newError {
                showError(error)
            }
        }
        .onAppear {
            Self.logger.debug("MainView appeared")
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Main navigation")
    }
    
    // MARK: - Helper Views
    @ViewBuilder
    private func tabItemView(for index: Int) -> some View {
        guard index < tabConfigs.count else {
            EmptyView()
            return
        }
        
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
            return Color(.espresso)
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
    func signUp(email: String, password: String) -> AnyPublisher<AuthUser?, Error> {
        Just(nil).setFailureType(to: Error.self).eraseToAnyPublisher()
    }
    
    func signIn(email: String, password: String) -> AnyPublisher<AuthUser?, Error> {
        Just(nil).setFailureType(to: Error.self).eraseToAnyPublisher()
    }
    
    func signOut() -> AnyPublisher<Void, Never> {
        Just(()).eraseToAnyPublisher()
    }
    
    func updateCurrentUserPassword(email: String, password: String, newPassword: String) -> AnyPublisher<Void, Error> {
        Just(()).setFailureType(to: Error.self).eraseToAnyPublisher()
    }
    
    func deleteCurrentUser(email: String, password: String) -> AnyPublisher<Void, Error> {
        Just(()).setFailureType(to: Error.self).eraseToAnyPublisher()
    }
}

struct MockEventService: EventService {
    func getEventFeed(uid: String) async throws -> [Event] { [] }
    func createOrUpdateEvent(_ event: Event) async throws -> Event { event }
    func deleteEvent(eventId: String, createdByUid: String) async throws {}
    func getEventsByStatus(uid: String, status: EventStatus) async throws -> [Event] { [] }
    func likeEvent(eventId: String, userID: String) async throws {}
    func unlikeEvent(eventId: String, userID: String) async throws {}
}

struct MockFriendshipService: FriendshipService {
    func sendFriendRequest(from: String, to: String, completion: @escaping (Result<Void, Error>) -> Void) {}
    func acceptFriendRequest(from: String, to: String, completion: @escaping (Result<Void, Error>) -> Void) {}
    func declineFriendRequest(from: String, to: String, completion: @escaping (Result<Void, Error>) -> Void) {}
    func getFriendRequests(for userId: String, completion: @escaping (Result<[String], Error>) -> Void) {}
}
