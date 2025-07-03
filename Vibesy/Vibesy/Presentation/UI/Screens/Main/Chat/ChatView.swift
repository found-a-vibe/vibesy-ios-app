//
//  ChatView.swift
//  Vibesy
//
//  Created by Alexander Cleoni on 3/1/25.
//

import SwiftUI
import StreamChatSwiftUI

struct ChatView: View {
    @ObservedObject var notificationCenter: VibesyNotificationCenter = .shared
    @SwiftUI.Environment(\.scenePhase) private var scenePhase
    
    @State private var refreshView = UUID()

    var body: some View {
        ChatChannelListView(
            viewFactory: CustomFactory.shared,
            title: "Chat",
            selectedChannelId: notificationCenter.notificationChannelId,
            handleTabBarVisibility: true,
            embedInNavigationView: true
        )
        .id(refreshView) // this forces a deep reinitialization
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                refreshView = UUID() // generates a new unique ID, ensuring full reload
            }
        }
    }
}
