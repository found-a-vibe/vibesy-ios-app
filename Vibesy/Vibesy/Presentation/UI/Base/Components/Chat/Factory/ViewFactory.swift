//
//  ViewFactory.swift
//  Vibesy
//
//  Created by Alexander Cleoni on 12/18/24.
//

import SwiftUI
import StreamChatSwiftUI

@MainActor
class CustomFactory: @preconcurrency ViewFactory {
    @Injected(\.chatClient) public var chatClient
    private init() {}
    public static let shared = CustomFactory()
    
    func makeChannelListHeaderViewModifier(title: String) -> some ChannelListHeaderViewModifier {
            CustomChannelModifier(title: title)
    }
    
    func makeNoChannelsView() -> some View {
        return NoContentView(image: UIImage(systemName: "message")!, title: "Let's start chatting", description: "Send your first message to a friend today!")
    }
}

