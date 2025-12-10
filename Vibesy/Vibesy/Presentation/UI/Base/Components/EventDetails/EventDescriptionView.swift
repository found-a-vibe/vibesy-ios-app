//
//  EventDescriptionView.swift
//  Vibesy
//
//  Created by Alexander Cleoni  on 12/8/25.
//

import SwiftUI

struct EventDescriptionView: View {
    let description: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Event Details")
                .font(.aBeeZeeRegular(size: 16))
            Text(description)
                .font(.aBeeZeeRegular(size: 12))
                .foregroundColor(.gray)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
