//
//  SheetCoordinator.swift
//  Vibesy
//
//  Created by Alexander Cleoni on 11/21/24.
//

/// A protocol representing a sheet in the Vibesy  application.
///
/// Types conforming to this protocol must have a unique identifier, allowing them
/// to be distinguished from other sheets.
protocol Sheet: Identifiable {}

/// A protocol for coordinators that manage sheets within the Vibesy application.
///
/// This protocol extends `BaseCoordinator` by introducing the ability to handle sheets
/// of a specified type. It provides a default implementation for presenting and dismissing sheets.
protocol SheetCoordinator: BaseCoordinator {
    
    /// The type of sheet that this coordinator manages.
    associatedtype SheetType: Sheet
    
    /// The currently active sheet, if any.
    var sheet: SheetType? { get set }
    
    /// Builds the main view for the specified sheet.
    /// - Parameter sheet: The sheet to build the view for.
    /// - Returns: The main view associated with the sheet.
    func buildSheet(sheet: SheetType) -> CoordinatorView
}

extension SheetCoordinator {
    
    /// Presents a sheet.
    ///
    /// This method sets the `sheet` property to the specified sheet.
    /// - Parameter sheet: The sheet to present.
    func presentSheet(_ sheet: SheetType) {
        self.sheet = sheet
    }
    
    /// Dismisses the currently active sheet.
    ///
    /// This method sets the `sheet` property to `nil`, effectively dismissing any
    /// active sheet.
    func dismissSheet() {
        self.sheet = nil
    }
}
