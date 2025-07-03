//
//  CustomChannelModifier.swift
//  LivingFit
//
//  Created by Alexander Cleoni on 6/1/24.
//

import SwiftUI
import StreamChat
import StreamChatSwiftUI

struct CustomChannelModifier: ChannelListHeaderViewModifier {
    @Injected(\.chatClient) var chatClient
    
    @State var isNewChatShown = false
    
    var title: String
    
    @State var profileShown = false
    
    func body(content: Content) -> some View {
        ZStack {
            content.toolbar {
                CustomChannelHeader(
                    title: title,
                    currentUserController: chatClient.currentUserController(),
                    isNewChatShown: $isNewChatShown
                )
            }
            .navigationDestination(isPresented: $isNewChatShown) {
                NewChatView(isNewChatShown: $isNewChatShown)
            }
        }
    }
}
