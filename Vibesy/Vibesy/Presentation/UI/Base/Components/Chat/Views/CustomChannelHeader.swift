//
//  CustomChannelHeader.swift
//  Vibesy
//
//  Created by Alexander Cleoni on 12/18/24.
//

import SwiftUI
import StreamChat
import StreamChatSwiftUI

public struct CustomChannelHeader: ToolbarContent {
    @Injected(\.fonts) var fonts
    @Injected(\.images) var images
    
    var title: String
    var currentUserController: CurrentChatUserController
    
    @Binding var isNewChatShown: Bool
    
    public var body: some ToolbarContent {
        ToolbarItem(placement: .principal) {
            Text(title)
                .foregroundStyle(.goldenBrown)
                .font(.aBeeZeeRegular(size: 26))
                .frame(maxWidth: .infinity, alignment: .center)
        }
        ToolbarItem(placement: .navigationBarTrailing) {
            Button {
                isNewChatShown = true
            } label: {
                Image(systemName: "square.and.pencil")
                    .foregroundStyle(.black)
            }
        }
    }
}
