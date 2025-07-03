//
//  ImageScrollingOverlayView.swift
//  FoundAVibe
//
//  Created by Alexander Cleoni on 10/23/24.
//

import SwiftUI

struct ImageScrollingOverlayView: View {
    @Binding var currentImageIndex: Int
    let totalImageCount: Int
    
    var body: some View {
        HStack {
            Rectangle()
                .onTapGesture {
                    decrement()
                }
            Rectangle()
                .onTapGesture {
                    increment()
                }
        }
        .foregroundStyle(.black.opacity(0.01))
    }
}

private extension ImageScrollingOverlayView {
    func increment() {
        if currentImageIndex < totalImageCount {
            currentImageIndex += 1
        } else {
            currentImageIndex = 0
        }
    }
    
    func decrement() {
        if currentImageIndex > 0 {
            currentImageIndex -= 1
        } else {
            currentImageIndex = totalImageCount
        }
    }
}

#Preview {
    ImageScrollingOverlayView(currentImageIndex: .constant(0), totalImageCount: 0)
}
