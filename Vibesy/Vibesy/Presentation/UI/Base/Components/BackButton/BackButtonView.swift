//
//  BackButtonView.swift
//  Vibesy
//
//  Created by Alexander Cleoni on 12/19/24.
//

import SwiftUI

struct BackButtonView: View {
    var systemImageName: String? = nil
    var action: () -> Void

    var body: some View {
        Button(action: {
            action()
        }) {
            RoundedRectangle(cornerRadius: 12)
                .fill(.white)
                .frame(width: 38, height: 38)
                .shadow(radius: 5)
                .overlay {
                    Image(systemName: systemImageName ?? "chevron.left")
                        .foregroundStyle(.espresso)
                }
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    BackButtonView(action: {})
}
