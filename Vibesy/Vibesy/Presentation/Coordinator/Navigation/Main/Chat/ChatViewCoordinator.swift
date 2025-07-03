//
//  HomeCoordinator.swift
//  Vibesy
//
//  Created by Alexander Cleoni on 12/15/24.
//
import SwiftUI

// Enum defining the pages managed by the WorkoutPageCoordinator
enum ChatPages: Hashable, Pages {
    case chatChannelListView
}

// Coordinator responsible for managing navigation within the workout module
class ChatPageCoordinator: ObservableObject, PageCoordinator {
    typealias CoordinatorView = AnyView
    typealias PagesType = ChatPages
    
    @Published var path: NavigationPath = NavigationPath()
    
    func build(page: PagesType, args: Any? = nil) -> AnyView {
        switch page {
        case .chatChannelListView:
            return AnyView(ChatView())
        }
    }
}

// View responsible for handling navigation and coordinating views
struct ChatViewCoordinator: View {
    @StateObject private var pageCoordinator = ChatPageCoordinator()
    
    var body: some View {
        NavigationStack(path: $pageCoordinator.path) {
            pageCoordinator.build(page: .chatChannelListView)
                .navigationDestination(for: ChatPages.self) { page in
                    pageCoordinator.build(page: page)
                }
        }
        .environmentObject(pageCoordinator)
    }
}
