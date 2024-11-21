//
//  PageCoordinator.swift
//  Vibesy
//
//  Created by Alexander Cleoni on 11/21/24.
//
import SwiftUI

protocol Pages: Hashable {}

protocol PageCoordinator: BaseCoordinator {
    associatedtype PagesType: Pages
    var path: NavigationPath { get set }
    
    func build(page: PagesType) -> CoordinatorView
}
extension PageCoordinator {
    func push(page: PagesType) {
        path.append(page)
    }
    
    func pop() {
        path.removeLast()
    }
    
    func popToRoot() {
        path.removeLast(path.count)
    }
}
