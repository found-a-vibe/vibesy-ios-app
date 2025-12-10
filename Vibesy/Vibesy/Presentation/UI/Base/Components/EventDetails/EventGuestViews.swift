//
//  EventGuestViews.swift
//  Vibesy
//
//  Created by Alexander Cleoni on 3/6/25.
//

import Kingfisher
import SwiftUI

// MARK: - Speaker/Guest Section
struct EventSpeakerGuestView: View {
    let guests: [Guest]
    
    var body: some View {
        VStack(alignment: .center) {
            Text("Speaker/Guest")
                .font(.aBeeZeeRegular(size: 16))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding([.top, .horizontal])
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(guests, id: \.self) { guest in
                        EventGuestCardView(
                            name: guest.name,
                            imageName: guest.imageUrl ?? "",
                            role: guest.role
                        )
                    }
                }
                .padding(.horizontal)
            }
        }
    }
}

// MARK: - Guest Card
struct EventGuestCardView: View {
    let name: String
    let imageName: String
    let role: String
    
    var body: some View {
        VStack(spacing: 8) {
            KFImage(URL(string: imageName))
                .placeholder {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 93, height: 97)
                        .overlay {
                            Image(systemName: "person.fill")
                                .foregroundColor(.gray)
                                .font(.title2)
                        }
                }
                .onFailure { error in
                    print("❌ Failed to load guest image: \(imageName)")
                    print("❌ Error: \(error.localizedDescription)")
                }
                .retry(maxCount: 3)
                .cacheOriginalImage()
                .fade(duration: 0.25)
                .resizable()
                .scaledToFill()
                .frame(width: 93, height: 97)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            
            VStack(spacing: 2) {
                Text(name)
                    .font(.aBeeZeeRegular(size: 14))
                    .fontWeight(.medium)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                Text(role)
                    .font(.aBeeZeeRegular(size: 12))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(1)
            }
        }
        .frame(width: 120)
    }
}
