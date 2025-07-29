//
//  AccountViewCoordinator.swift
//  Vibesy
//
//  Created by Alexander Cleoni on 12/17/24.
//

import SwiftUI

// Enum defining the pages managed by the WorkoutPageCoordinator
enum AccountPages: String, Hashable, Codable, Pages {
    case accountView = "accountView"
    case profileDetails = "profileDetails"
    case postedEvents = "postedEvents"
    case attendedEvents = "attendedEvents"
    case reservedEvents = "reservedEvents"
    case profileDetailsEdit = "profileDetailsEdit"
    case eventDetails = "eventDetails"
    case matchedUserDetails = "matchedUserDetails"
}

// Coordinator responsible for managing navigation within the workout module
class AccountPageCoordinator: ObservableObject, PageCoordinator {
    typealias CoordinatorView = AnyView
    typealias PagesType = AccountPages
    
    @Published var path: NavigationPath = NavigationPath()
    @Published var enableAdminMode: Bool = false
    
    func build(page: PagesType, args: Any? = nil) -> AnyView {
        switch page {
        case .accountView:
            return AnyView(AccountView())
        case .profileDetails:
            return AnyView(ProfileDetailsView() { direction in
                if direction == .back {
                    self.pop()
                }
                if direction == .forward {
                    self.push(page: .profileDetailsEdit)
                }
            }
                .toolbar(.hidden, for: .tabBar)
                .navigationBarBackButtonHidden())
        case .postedEvents:
            return AnyView(EventListView(eventsHeaderViewText: "Posted Events", eventsByStatus: .postedEvents) { direction in
                if direction == .root {
                    self.popToRoot()
                }
                if direction == .forward {
                    self.enableAdminMode = true
                    self.push(page: .eventDetails)
                }
            }
                .toolbar(.hidden, for: .tabBar)
                .navigationBarBackButtonHidden())
        case .attendedEvents:
            return AnyView(EmptyView().tint(.goldenBrown))
        case .reservedEvents:
            return AnyView(EventListView(eventsHeaderViewText: "Reserved Events", eventsByStatus: .reservedEvents) { direction in
                if direction == .root {
                    self.popToRoot()
                }
                if direction == .forward {
                    self.push(page: .eventDetails)
                }
            }
                .toolbar(.hidden, for: .tabBar)
                .navigationBarBackButtonHidden())
        case .eventDetails:
            return AnyView(EventScreenView(enableAdminMode: enableAdminMode) { direction in
                if direction == .back {
                    self.pop()
                }
                if direction == .forward {
                    self.push(page: .matchedUserDetails)
                }
            }.navigationBarBackButtonHidden())
        case .profileDetailsEdit:
            return AnyView(ProfileDetailsEditView() { direction in
                if direction == .back {
                    self.pop()
                }
            }.navigationBarBackButtonHidden())
        case .matchedUserDetails:
            return AnyView(MatchedUserDetailsView() { direction in
                if direction == .back {
                    self.pop()
                }
            }.navigationBarBackButtonHidden())
        }
    }
}

// View responsible for handling navigation and coordinating views
struct AccountViewCoordinator: View {
    @StateObject private var pageCoordinator = AccountPageCoordinator()
    
    var body: some View {
        NavigationStack(path: $pageCoordinator.path) {
            pageCoordinator.build(page: .accountView)
                .navigationDestination(for: AccountPages.self) { page in
                    pageCoordinator.build(page: page)
                }
        }
        .environmentObject(pageCoordinator)
    }
}
