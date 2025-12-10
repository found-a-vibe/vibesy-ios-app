//
//  EventLikesAndReservationsView.swift
//  Vibesy
//
//  Created by Alexander Cleoni  on 12/8/25.
//

import SwiftUI

struct EventLikesAndReservationsView: View {
    let likesCount: Int
    let reservationsCount: Int
    var body: some View {
        HStack(spacing: 20) {
            HStack {
                Image(systemName: "heart.fill")
                    .foregroundColor(.red)
                Text("\(likesCount) \(likesCount == 1 ? "Like" : "Likes")")
                    .font(.aBeeZeeRegular(size: 14))
                    .foregroundColor(.secondary)
            }
            HStack {
                Image(systemName: "person.2.fill")
                    .foregroundColor(.goldenBrown)
                Text(
                    "\(reservationsCount) \(reservationsCount == 1 ? "Reservation" : "Reservations")"
                )
                .font(.aBeeZeeRegular(size: 14))
                .foregroundColor(.secondary)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
