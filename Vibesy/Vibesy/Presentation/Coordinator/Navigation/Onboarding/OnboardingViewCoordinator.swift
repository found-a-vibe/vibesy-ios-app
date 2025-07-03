//
//  OnboardingViewCoordinator.swift
//  Vibesy
//
//  Created by Alexander Cleoni on 12/16/24.
//

import SwiftUI

// Enum defining the pages managed by the WorkoutPageCoordinator
enum OnboardingPages: Hashable, Pages {
    case profileNameView
    case profileAgeView
    case profileInterestsView
    case profileImagePickerView
}

// Coordinator responsible for managing navigation within the workout module
class OnboardingPageCoordinator: ObservableObject, PageCoordinator {
    typealias CoordinatorView = AnyView
    typealias PagesType = OnboardingPages
    
    @Published var path: NavigationPath = NavigationPath()
    
    func build(page: PagesType, args: Any? = nil) -> AnyView {
        switch page {
        case .profileNameView:
            return AnyView(ProfileNameView().navigationBarBackButtonHidden())
        case .profileAgeView:
            return AnyView(ProfileAgeView().navigationBarBackButtonHidden())
        case .profileInterestsView:
            return AnyView(ProfileInterestsView().navigationBarBackButtonHidden())
        case .profileImagePickerView:
            return AnyView(ProfileImagePickerView().navigationBarBackButtonHidden())
        }
    }
}

// View responsible for handling navigation and coordinating views
struct OnboardingViewCoordinator: View {
    @StateObject private var pageCoordinator = OnboardingPageCoordinator()
    
    var body: some View {
        NavigationStack(path: $pageCoordinator.path) {
            pageCoordinator.build(page: .profileNameView)
                .navigationDestination(for: OnboardingPages.self) { page in
                    pageCoordinator.build(page: page)
                }
        }
        .tint(.goldenBrown)
        .environmentObject(pageCoordinator)
    }
}
