//
//  Guest.swift
//  FoundAVibe
//
//  Created by Alexander Cleoni on 12/13/24.
//
import Foundation
import SwiftUI

struct Guest: Hashable {
    let id: UUID
    let name: String
    let role: String
    let image: UIImage?
    var imageUrl: String?
}
