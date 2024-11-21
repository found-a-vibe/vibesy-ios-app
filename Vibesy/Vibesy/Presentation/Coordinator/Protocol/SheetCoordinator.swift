//
//  SheetCoordinator.swift
//  Vibesy
//
//  Created by Alexander Cleoni on 11/21/24.
//
protocol Sheet: Identifiable {}

protocol SheetCoordinator: BaseCoordinator {
    associatedtype SheetType: Sheet
    var sheet: SheetType? { get set }
    
    func buildSheet(sheet: SheetType) -> CoordinatorView
}
extension SheetCoordinator {
    func presentSheet(_ sheet: SheetType) {
        self.sheet = sheet
    }
    
    func dismissSheet() {
        self.sheet = nil
    }
}
