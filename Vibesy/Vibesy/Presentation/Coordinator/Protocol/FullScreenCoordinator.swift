//
//  FullScreenCoordinator.swift
//  Vibesy
//
//  Created by Alexander Cleoni on 11/21/24.
//

/// A protocol representing a full-screen cover in the Vibesy application.
///
/// Types conforming to this protocol must have a unique identifier, allowing them
/// to be distinguished from other full-screen covers.
protocol FullScreenCover: Identifiable {}

/// A protocol for coordinators that manage full-screen covers within the Vibesy application.
///
/// This protocol extends `BaseCoordinator` by introducing the ability to handle full-screen covers
/// of a specified type. It provides a default implementation for presenting and dismissing covers.
protocol FullScreenCoverCoordinator: BaseCoordinator {

    /// The type of full-screen cover that this coordinator manages.
    associatedtype FullScreenCoverType: FullScreenCover
    
    /// The currently active full-screen cover, if any.
    var fullScreenCover: FullScreenCoverType? { get set }
    
    /// Builds the main view for the specified full-screen cover.
    /// - Parameter cover: The full-screen cover to build the view for.
    /// - Returns: The main view associated with the full-screen cover.
    func buildCover(cover: FullScreenCoverType) -> CoordinatorView
}

extension FullScreenCoverCoordinator {
    
    /// Presents a full-screen cover.
    ///
    /// This method sets the `fullScreenCover` property to the specified cover.
    /// - Parameter cover: The full-screen cover to present.
    func presentFullScreenCover(_ cover: FullScreenCoverType) {
        self.fullScreenCover = cover
    }
    
    /// Dismisses the currently active full-screen cover.
    ///
    /// This method sets the `fullScreenCover` property to `nil`, effectively dismissing any
    /// active full-screen cover.
    func dismissCover() {
        self.fullScreenCover = nil
    }
}
