//
//  HomeCoordinator.swift
//  Vibesy
//
//  Created by Alexander Cleoni on 12/15/24.
//
import SwiftUI

// Enum defining the pages managed by the WorkoutPageCoordinator
enum HomePages: Hashable, Pages {
    case authenticationView
    case onboardingView
    case forgotPasswordView
    case otpVerificationView
    case updatePasswordView
}

// Coordinator responsible for managing navigation within the workout module
class HomePageCoordinator: ObservableObject, PageCoordinator {
    typealias CoordinatorView = AnyView
    typealias PagesType = HomePages
    
    @Published var path: NavigationPath = NavigationPath()
    
    func build(page: PagesType, args: Any? = nil) -> AnyView {
        switch page {
        case .authenticationView:
            return AnyView(AuthenticationView())
        case .onboardingView:
            return AnyView(OnboardingView())
        case .forgotPasswordView:
            return AnyView(ForgotPasswordView())
        case .otpVerificationView:
            return AnyView(OTPVerificationView())
        case .updatePasswordView:
            return AnyView(UpdatePasswordView())
        }
    }
}

// View responsible for handling navigation and coordinating views
struct HomeViewCoordinator: View {
    @StateObject private var pageCoordinator = HomePageCoordinator()
    
    var body: some View {
        NavigationStack(path: $pageCoordinator.path) {
            pageCoordinator.build(page: .authenticationView)
                .navigationDestination(for: HomePages.self) { page in
                    pageCoordinator.build(page: page)
                }
        }
        .environmentObject(pageCoordinator)
    }
}
