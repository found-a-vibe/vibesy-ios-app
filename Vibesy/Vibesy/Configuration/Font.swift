//
//  Font.swift
//  Vibesy
//
//  Created by Alexander Cleoni on 12/15/24.
//
import SwiftUI

extension Font {
    public static func abeezee(size: CGFloat) -> Font {
        Font.custom("ABeeZee-Regular", size: size)
    }
    
    public static func abeezeeItalic(size: CGFloat) -> Font {
        Font.custom("ABeeZee-Italic", size: size)
    }
    
    public static func poppins(size: CGFloat) -> Font {
        Font.custom("Poppins-Regular", size: size)
    }
}
