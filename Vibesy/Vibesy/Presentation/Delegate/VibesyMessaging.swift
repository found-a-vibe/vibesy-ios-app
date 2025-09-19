//
//  VibesyMessaging.swift
//  Vibesy
//
//  Created by Alexander Cleoni on 1/24/25.
//

import FirebaseMessaging
import FirebaseAuth
import StreamChat
import StreamChatSwiftUI
import SwiftUI


class VibesyMessaging: NSObject, MessagingDelegate {
    @Injected(\.chatClient) public var chatClient

    var tokenModel = TokenModel(service: FirebaseTokenService())
    
    @MainActor static let shared = VibesyMessaging()
    
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        if let token = Messaging.messaging().fcmToken {
            if let uid = Auth.auth().currentUser?.uid {
                tokenModel.saveDeviceRegistrationToken(forUserWithId: uid, token)
            }
            chatClient.currentUserController().addDevice(.firebase(token: token, providerName: "vibesy-push-notifications")) { error in
                if let error = error {
                    log.warning("adding a device failed with an error \(error)")
                }
            }
        }
    }
}
