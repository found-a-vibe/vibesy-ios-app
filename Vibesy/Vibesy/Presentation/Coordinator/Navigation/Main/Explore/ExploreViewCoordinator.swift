//
//  ExploreViewCoordinator.swift
//  Vibesy
//
//  Created by Alexander Cleoni on 12/15/24.
//

import SwiftUI

// Enum defining the pages managed by the WorkoutPageCoordinator
enum ExplorePages: Hashable, Pages {
    case exploreView
    case notificationView
    case matchedUserDetails
    case profileDetails
    case profileDetailsEdit
}


// Coordinator responsible for managing navigation within the explore module
class ExplorePageCoordinator: ObservableObject, PageCoordinator {
    typealias CoordinatorView = AnyView
    typealias PagesType = ExplorePages
    
    @Published var path: NavigationPath = NavigationPath()
    
    func build(page: PagesType, args: Any? = nil) -> AnyView {
        switch page {
        case .exploreView:
            return AnyView(ExploreView())
        case .notificationView:
            return AnyView(NotificationView().toolbarVisibility(.hidden, for: .tabBar).navigationBarBackButtonHidden())
        case .matchedUserDetails:
            return AnyView(MatchedUserDetailsView() { direction in
                if direction == .back {
                    self.pop()
                }
            }.navigationBarBackButtonHidden())
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
        case .profileDetailsEdit:
            return AnyView(ProfileDetailsEditView() { direction in
                if direction == .back {
                    self.pop()
                }
            }.navigationBarBackButtonHidden())
        }
    }
}

// View responsible for handling navigation and coordinating views
struct ExploreViewCoordinator: View {
    @StateObject private var pageCoordinator = ExplorePageCoordinator()
    
    var body: some View {
        NavigationStack(path: $pageCoordinator.path) {
            pageCoordinator.build(page: .exploreView)
                .navigationDestination(for: ExplorePages.self) { page in
                    pageCoordinator.build(page: page)
                }
        }
        .environmentObject(pageCoordinator)
    }
}
