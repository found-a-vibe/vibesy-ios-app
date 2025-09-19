//
//  AppDelegate.swift
//  Vibesy
//
//  Created by Alexander Cleoni on 11/22/24.
//
import os
import FirebaseCore
import FirebaseMessaging
import StreamChat
import StreamChatSwiftUI
import SwiftUI

class AppDelegate: NSObject, UIApplicationDelegate, MessagingDelegate {
    let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "Vibesy", category: "AppDelegate")

    var streamChat: StreamChat?
    
    var chatClient: ChatClient = {
        //For the tutorial we use a hard coded api key and application group identifier
        var config = ChatClientConfig(apiKey: .init("82jbxje682kj"))
        config.isLocalStorageEnabled = true

        var colors = ColorPalette()
        colors.tintColor = Color(.sandstone)
    
        let appearance = Appearance(colors: colors)
        // The resulting config is passed into a new `ChatClient` instance.
        let client = ChatClient(config: config)
        return client
    }()
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        //Use Firebase library to configure APIs
        FirebaseApp.configure()
        logger.info("Firebase initialized")
        
        Messaging.messaging().delegate = VibesyMessaging.shared
        logger.info("Firebase Messaging initialized")
        
        UNUserNotificationCenter.current().delegate = VibesyNotificationCenter.shared
        
        streamChat = StreamChat(chatClient: chatClient)
        
        return true
    }
    
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        Messaging.messaging().apnsToken = deviceToken
    }
}
