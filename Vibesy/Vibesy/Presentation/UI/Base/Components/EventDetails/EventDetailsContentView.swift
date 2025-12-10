//
//  EventDetailsContentView.swift
//  Vibesy
//
//  Created by Alexander Cleoni on 3/6/25.
//

import SwiftUI

struct EventDetailsContentView: View {
    let location: String
    let date: String
    let timeRange: String
    
    var body: some View {
        VStack(spacing: 24) {
            // Likes and Reservations Count Row
            HStack {
                Image("Location")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 24, height: 24)
                Text(location)
                    .font(.aBeeZeeRegular(size: 16))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            HStack {
                Image(systemName: "calendar")
                VStack(alignment: .leading, spacing: 8) {
                    Text("\(date)")
                        .font(.aBeeZeeRegular(size: 16))
                    Text("\(timeRange)")
                        .font(.aBeeZeeRegular(size: 12))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding([.top, .horizontal])
    }
}
