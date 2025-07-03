//
//  LikedEventCoordinator.swift
//  Vibesy
//
//  Created by Alexander Cleoni on 12/19/24.
//

import SwiftUI

// Enum defining the pages managed by the WorkoutPageCoordinator
enum LikedEventPages: Hashable, Pages {
    case likedEvents
    case likedEventDetails
    case matchedUserDetails
}

// Coordinator responsible for managing navigation within the workout module
class LikedEventPageCoordinator: ObservableObject, PageCoordinator {
    typealias CoordinatorView = AnyView
    typealias PagesType = LikedEventPages
    
    @Published var path: NavigationPath = NavigationPath()
    
    func build(page: PagesType, args: Any? = nil) -> AnyView {
        switch page {
        case .likedEvents:
            return AnyView(LikedEventsView())
        case .likedEventDetails:
            return AnyView(EventScreenView() { direction in
                if direction == .back {
                    self.pop()
                }
                if direction == .forward {
                    self.push(page: .matchedUserDetails)
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
struct LikedEventsViewCoordinator: View {
    @StateObject private var pageCoordinator = LikedEventPageCoordinator()
    
    var body: some View {
        NavigationStack(path: $pageCoordinator.path) {
            pageCoordinator.build(page: .likedEvents)
                .navigationDestination(for: LikedEventPages.self) { page in
                    pageCoordinator.build(page: page)
                }
        }
        .environmentObject(pageCoordinator)
    }
}
