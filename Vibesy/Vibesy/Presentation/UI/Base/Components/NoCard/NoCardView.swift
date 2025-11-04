//
//  NoCardView.swift
//  Vibesy
//
//  Created by Alexander Cleoni on 12/17/24.
//

import SwiftUI

struct NoCardView: View {
    var onRefresh: () -> Void // Closure to handle refresh action
    
    var body: some View {
        VStack(spacing: 20) {
            // Illustration or placeholder image
            Image(systemName: "rectangle.stack.fill")
                .resizable()
                .scaledToFit()
                .frame(width: 120, height: 120)
                .foregroundColor(.sandstone.opacity(0.6))
            
            // Informational text
            Text("You're all caught up!")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.espresso)
            
            Text("More Vibes Are Coming.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            // Refresh button
            Button {
                onRefresh()
            } label: {
                Image("Refresh")
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 24, height: 24)
                    .foregroundStyle(.goldenBrown)
                    .background {
                        Circle()
                            .fill(Color.white)
                            .frame(width: 48, height: 48)
                            .shadow(radius: 5)
                    }
                
            }
            .buttonStyle(.plain)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        //        .background(Color(.systemGroupedBackground))
    }
}

#Preview {
    NoCardView() {
        print("refreshing")
    }
}
