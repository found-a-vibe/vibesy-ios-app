//
//  CardImageIndicatorView.swift
//  FoundAVibe
//
//  Created by Alexander Cleoni on 10/24/24.
//

import SwiftUI

struct CardImageIndicatorView: View {
    let currentIndex: Int
    let totalImageCount: Int
    
    var body: some View {
        HStack {
            ForEach(0..<totalImageCount, id: \.self) { index in
                Capsule()
                    .fill(index == currentIndex ? .white : .gray)
                    .frame(width: cardImageIndicatorWidth, height: 4)
                    .padding(.top, 8)
            }
        }
    }
}

extension CardImageIndicatorView {
    private var cardImageIndicatorWidth: CGFloat {
        return SizeConstants.width / CGFloat(totalImageCount) - 28
    }
}

#Preview {
    CardImageIndicatorView(currentIndex: 0, totalImageCount: 5)
        .preferredColorScheme(.dark)
}
