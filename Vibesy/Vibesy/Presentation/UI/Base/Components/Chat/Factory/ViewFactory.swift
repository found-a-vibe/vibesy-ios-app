//
//  ViewFactory.swift
//  Vibesy
//
//  Created by Alexander Cleoni on 12/18/24.
//

import SwiftUI
import StreamChatSwiftUI

class CustomFactory: ViewFactory {
    @Injected(\.chatClient) public var chatClient
    private init() {}
    public static let shared = CustomFactory()
    
    func makeChannelListHeaderViewModifier(title: String) -> some ChannelListHeaderViewModifier {
            CustomChannelModifier(title: title)
    }
    
    func makeNoChannelsView() -> some View {
        VStack(spacing: 20) {
            Image(systemName: "message")
                .resizable()
                .scaledToFit()
                .frame(maxWidth: 120)
                .foregroundStyle(.espresso)
            Text("Ready to Connect?")
                .font(.abeezee(size: 24))
                .bold()
            Text("Stay tuned, you’ll be able to slide in someone’s dms soon!")
                .multilineTextAlignment(.center)
                .font(.subheadline)
        }
        .padding()
    }
}

