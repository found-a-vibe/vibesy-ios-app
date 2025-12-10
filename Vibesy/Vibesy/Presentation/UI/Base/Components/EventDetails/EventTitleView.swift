//
//  EventTitleView.swift
//  Vibesy
//
//  Created by Alexander Cleoni  on 12/8/25.
//

import SwiftUI

struct EventTitleView: View {
    let eventTitle: String

    
    var body: some View {
        VStack(alignment: .leading) {
            Text(eventTitle)
                .font(.aBeeZeeRegular(size: 28))
                .foregroundStyle(Color(.white))
                .padding(.top, 8)
            
        }
        .padding(.horizontal)
    }
}
