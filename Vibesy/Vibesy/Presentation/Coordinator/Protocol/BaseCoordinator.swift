//
//  BaseCoordinator.swift
//  Vibesy
//
//  Created by Alexander Cleoni on 11/21/24.
//
import SwiftUI

/// A protocol that defines the base structure for a coordinator in the Vibesy application.
///
/// This protocol requires conforming types to specify a `CoordinatorView`, which represents
/// the main view managed by the coordinator.
protocol BaseCoordinator: AnyObject {
    associatedtype CoordinatorView: View
}
