//
//  NewEventViewCoordinator.swift
//  LivingFit
//
//  Created by Alexander Cleoni on 11/24/24.
//

import SwiftUI

// Enum defining the pages managed by the NewEventPageCoordinator
enum NewEventPages: Hashable, Pages {
    case noNewEvent
    case newEvent1
}

// Enum defining the full screen covers managed by the NewEventFullScreenCoordinator
enum NewEventFullScreenCovers: String, Identifiable, FullScreenCover {
    var id: String {
        self.rawValue
    }
    case newEvent0
}

// Coordinator responsible for managing navigation within the new event module
class NewEventPageCoordinator: ObservableObject, PageCoordinator {
    typealias CoordinatorView = AnyView
    typealias PagesType = NewEventPages
    
    @Published var path: NavigationPath = NavigationPath()
    
    func build(page: PagesType, args: Any? = nil) -> AnyView {
        switch page {
        case .noNewEvent:
            return AnyView(EmptyView())
        case .newEvent1:
            return AnyView(NewEventView1(isNewEventViewPresented: .constant(false)))
        }
    }
}

class NewEventFullScreenCoverCoordinator: ObservableObject, FullScreenCoverCoordinator {
    typealias CoordinatorView = AnyView
    typealias FullScreenCoverType = NewEventFullScreenCovers
    
    @Published var fullScreenCover: FullScreenCoverType?
    
    func buildCover(cover: FullScreenCoverType) -> AnyView {
        switch cover {
        case .newEvent0:
            return AnyView(NewEventView0(isNewEventViewPresented: .constant(false)))
        }
    }
}

// View responsible for handling navigation and coordinating views
struct NewEventViewCoordinator: View {
    @StateObject private var pageCoordinator = NewEventPageCoordinator()
    @StateObject private var fullScreenCoverCoordinator = NewEventFullScreenCoverCoordinator()
    
    var body: some View {
        NavigationStack(path: $pageCoordinator.path) {
            pageCoordinator.build(page: .noNewEvent)
                .navigationDestination(for: NewEventPages.self) { page in
                    pageCoordinator.build(page: page)
                }
                .fullScreenCover(item: $fullScreenCoverCoordinator.fullScreenCover) { item in
                    fullScreenCoverCoordinator.buildCover(cover: item)
                }
        }
        .environmentObject(pageCoordinator)
        .environmentObject(fullScreenCoverCoordinator)
    }
}
