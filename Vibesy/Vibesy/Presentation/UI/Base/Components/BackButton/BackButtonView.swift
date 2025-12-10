//
//  BackButtonView.swift
//  Vibesy
//
//  Created by Alexander Cleoni on 12/19/24.
//

import SwiftUI

struct BackButtonView: View {
    var systemImageName: String? = nil
    var rounded: Bool = true
    var color: Color = .espresso
    var action: () -> Void
    
    var body: some View {
        Button(action: {
            action()
        }) {
            if rounded == true {
                RoundedRectangle(cornerRadius: 12)
                    .fill(.clear)
                    .frame(width: 38, height: 38)
                    .shadow(radius: 5)
                    .overlay {
                        Image(systemName: systemImageName ?? "chevron.left")
                            .foregroundStyle(color)
                    }
            } else {
                Image(systemName: systemImageName ?? "chevron.left")
                    .foregroundStyle(color)
            }
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    BackButtonView(action: {})
}
