//
//  TagModel.swift
//  Vibesy
//
//  Created by Alexander Cleoni on 3/20/25.
//

import Foundation

public enum TagFieldStyle {
    case RoundedBorder
    case Modern
    case Multilined
}

extension String {
    func isContainSpaceAndNewlines() -> Bool {
        return rangeOfCharacter(from: .whitespacesAndNewlines) != nil
    }
}
