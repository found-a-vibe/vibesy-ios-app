//
//  VibesyNotificationCenter.swift
//  Vibesy
//
//  Created by Alexander Cleoni on 1/24/25.
//
import SwiftUI
import StreamChat
import StreamChatSwiftUI

class VibesyNotificationCenter: NSObject, ObservableObject, UNUserNotificationCenterDelegate  {
    @Injected(\.chatClient) private var chatClient
    @Published var notificationChannelId: String?
    @Published var navigateToPushNotifications: Bool?

    @MainActor static let shared = VibesyNotificationCenter()
    
    private var center: UNUserNotificationCenter {
        UNUserNotificationCenter.current()
    }
    
    private var authorizationOptions: UNAuthorizationOptions {
        [.alert, .sound, .badge]
    }
    
    override private init() {}
    
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        defer { completionHandler() }
        
        guard let notificationInfo = try? ChatPushNotificationInfo(content: response.notification.request.content) else {
            self.navigateToPushNotifications = true
            return
        }
        
        guard let cid = notificationInfo.cid else { return }
        
        guard case UNNotificationDefaultActionIdentifier = response.actionIdentifier else { return }
        
        self.notificationChannelId = cid.description
    }
    
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        if #available(iOS 14.0, *) {
            completionHandler([.badge, .banner])
        } else {
            completionHandler([.badge])
        }
    }
    
    func registerForPushNotifications() {
        center.requestAuthorization(options: authorizationOptions) { [weak self] granted, _ in
            print("Permission granted: \(granted)")
            self?.getNotificationSettings()
        }
    }
    
    private func getNotificationSettings() {
        center.getNotificationSettings { settings in
            print("Notification settings: \(settings)")
            guard settings.authorizationStatus == .authorized else { return }
            
            DispatchQueue.main.async {
                UIApplication.shared.registerForRemoteNotifications()
            }
        }
    }
}
