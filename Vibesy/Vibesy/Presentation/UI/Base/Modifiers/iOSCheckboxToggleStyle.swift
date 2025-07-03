//
//  iOSCheckboxToggleStyle.swift
//  Vibesy
//
//  Created by Alexander Cleoni on 12/15/24.
//

import SwiftUI

struct iOSCheckboxToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        Button(action: {
            configuration.isOn.toggle()
        }, label: {
            HStack {
                Image(systemName: configuration.isOn ? "checkmark.square" : "square")
                configuration.label
            }
        })
        .buttonStyle(.plain)
    }
}
