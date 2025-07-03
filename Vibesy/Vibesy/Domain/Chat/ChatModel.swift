//
//  ChatModel.swift
//  Vibesy
//
//  Created by Alexander Cleoni on 12/17/24.
//
import Foundation
import StreamChat
import StreamChatSwiftUI
import SwiftUI

class ChatModel: ObservableObject {
    @Injected(\.chatClient) public var chatClient
    
    @Published var selectedChannelId: String?
    
    func connectUser(userId: String, name: String, imageURL: URL?) {
        chatClient.connectUser(
            userInfo: .init(
                id: userId,
                name: name,
                imageURL: imageURL
            ),
            token: .development(userId: userId)
        ) { error in
            if let error = error {
                // Some very basic error handling only logging the error.
                log.error("connecting the user failed \(error)")
                return
            }
        }
    }
}
