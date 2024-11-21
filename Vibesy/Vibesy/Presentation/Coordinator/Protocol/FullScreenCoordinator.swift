//
//  FullScreenCoordinator.swift
//  Vibesy
//
//  Created by Alexander Cleoni on 11/21/24.
//
protocol FullScreenCover: Identifiable {}

protocol FullScreenCoverCoordinator: BaseCoordinator {
    associatedtype FullScreenCoverType: FullScreenCover
    var fullScreenCover: FullScreenCoverType? { get set }
    
    func buildCover(cover: FullScreenCoverType) -> CoordinatorView
}
extension FullScreenCoverCoordinator {
    func presentFullScreenCover(_ cover: FullScreenCoverType) {
        self.fullScreenCover = cover
    }
    
    func dismissCover() {
        self.fullScreenCover = nil
    }
}
