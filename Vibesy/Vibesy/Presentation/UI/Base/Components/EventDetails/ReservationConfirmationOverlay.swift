//
//  ReservationConfirmationOverlay.swift
//  Vibesy
//
//  Created by Alexander Cleoni on 3/6/25.
//

import SwiftUI

struct ReservationConfirmationOverlay: View {
    let isConfirmation: Bool
    let onConfirm: () -> Void
    
    var body: some View {
        RoundedRectangle(cornerRadius: 20)
            .fill(
                LinearGradient(
                    gradient: Gradient(colors: [
                        .goldenBrown,
                        .espresso,
                    ]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .frame(maxWidth: 393, maxHeight: 155)
            .padding()
            .overlay {
                VStack(alignment: .center, spacing: 12) {
                    if isConfirmation {
                        confirmationContent
                    } else {
                        cancellationContent
                    }
                    
                    Button(action: onConfirm) {
                        Text(isConfirmation ? "Confirm" : "Cancel")
                            .font(.aBeeZeeRegular(size: 12))
                            .foregroundColor(.white)
                            .frame(width: 124, height: 28)
                            .padding(2)
                            .background(.goldenBrown)
                            .cornerRadius(8)
                    }
                }
                .foregroundStyle(.white)
            }
            .animation(.easeInOut, value: isConfirmation)
    }
    
    // MARK: - Subviews
    
    private var confirmationContent: some View {
        Group {
            Text("Get Ready to Vibe!")
                .font(.aBeeZeeRegular(size: 20))
                .multilineTextAlignment(.center)
            
            Text("Your RSVP is confirmed.\nYou can manage your reservation from your profile.")
                .font(.aBeeZeeRegular(size: 16))
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
    }
    
    private var cancellationContent: some View {
        Group {
            Text("Are You Sure?")
                .font(.aBeeZeeRegular(size: 20))
            
            Text("If you bought your tickets online, please request a refund directly from the original ticket provider.")
                .font(.aBeeZeeRegular(size: 14))
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
    }
}
