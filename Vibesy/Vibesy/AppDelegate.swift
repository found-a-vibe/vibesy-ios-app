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
import Kingfisher
// Add Stripe import - Add package first: https://github.com/stripe/stripe-ios
@preconcurrency import StripePaymentSheet
@preconcurrency import StripeCore

class AppDelegate: NSObject, UIApplicationDelegate, MessagingDelegate {
    let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "Vibesy", category: "AppDelegate")

    var streamChat: StreamChat?
    
    var chatClient: ChatClient = {
        //For the tutorial we use a hard coded api key and application group identifier
        var config = ChatClientConfig(apiKey: .init("82jbxje682kj"))
        config.isLocalStorageEnabled = true

        var colors = ColorPalette()
        colors.tintColor = Color(.goldenBrown)
    
        let appearance = Appearance(colors: colors)
        // The resulting config is passed into a new `ChatClient` instance.
        let client = ChatClient(config: config)
        return client
    }()
    
    @MainActor
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        //Use Firebase library to configure APIs
        FirebaseApp.configure()
        logger.info("Firebase initialized")
        
        Messaging.messaging().delegate = VibesyMessaging.shared
        logger.info("Firebase Messaging initialized")
        
        UNUserNotificationCenter.current().delegate = VibesyNotificationCenter.shared
        
        StripeAPI.defaultPublishableKey = StripeConfig.publishableKey
        
        streamChat = StreamChat(chatClient: chatClient)
        
        // Configure Kingfisher for better image performance
        configureKingfisher()
        
        return true
    }
    
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        Messaging.messaging().apnsToken = deviceToken
    }
    
    // MARK: - Kingfisher Configuration
    
    private func configureKingfisher() {
        // Configure memory cache
        let cache = ImageCache.default
        
        // Set memory cache size to 100MB (good for user/guest profile images)
        cache.memoryStorage.config.totalCostLimit = 100 * 1024 * 1024
        
        // Set disk cache size to 500MB
        cache.diskStorage.config.sizeLimit = 500 * 1024 * 1024
        
        // Set cache expiration to 7 days for better performance
        cache.diskStorage.config.expiration = .days(7)
        
        // Configure downloader for better performance
        let downloader = ImageDownloader.default
        
        // Increase concurrent download limit for faster batch loading
        downloader.downloadTimeout = 30.0
        
        logger.info("Kingfisher configured: Memory=100MB, Disk=500MB, Expiration=7days")
    }
}

