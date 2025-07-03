//
//  SizeConstants.swift
//  FoundAVibe
//
//  Created by Alexander Cleoni on 10/22/24.
//
import SwiftUI

struct SizeConstants {
    static var screenCutoff: CGFloat {
        (UIScreen.main.bounds.width / 2) * 0.8
    }
    static var width: CGFloat {
        UIScreen.main.bounds.width - 20
    }
    static var height: CGFloat {
        UIScreen.main.bounds.height / 1.45
    }
}
