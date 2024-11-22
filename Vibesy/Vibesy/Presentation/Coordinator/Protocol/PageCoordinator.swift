//
//  PageCoordinator.swift
//  Vibesy
//
//  Created by Alexander Cleoni on 11/21/24.
//
import SwiftUI

/// A protocol representing a navigable page in the Vibesy application.
///
/// Types conforming to this protocol must be hashable, allowing them to be stored in
/// collections like `Set` or used as keys in dictionaries.
protocol Pages: Hashable {}

/// A protocol for coordinators that manage navigation through pages within a SwiftUI application.
///
/// This protocol extends `BaseCoordinator` by introducing the ability to handle a navigation path
/// and manage pages of a specified type. It provides default implementations for common navigation
/// actions such as pushing, popping, and resetting the navigation path.
protocol PageCoordinator: BaseCoordinator {
    
    /// The type of pages that this coordinator manages.
    associatedtype PagesType: Pages
    
    /// The navigation path representing the current stack of pages.
    var path: NavigationPath { get set }
    
    /// Builds the main view for the specified page.
    /// - Parameter page: The page to build the view for.
    /// - Returns: The main view associated with the page.
    func build(page: PagesType) -> CoordinatorView
}

extension PageCoordinator {
    
    /// Pushes a new page onto the navigation stack.
    ///
    /// This method appends the specified page to the `path`.
    /// - Parameter page: The page to push onto the navigation stack.
    func push(page: PagesType) {
        path.append(page)
    }
    
    /// Pops the top page from the navigation stack.
    ///
    /// This method removes the last page in the `path`, navigating back to the previous page.
    func pop() {
        path.removeLast()
    }
    
    /// Pops all pages to return to the root of the navigation stack.
    ///
    /// This method clears the navigation path, leaving only the root view.
    func popToRoot() {
        path.removeLast(path.count)
    }
}
