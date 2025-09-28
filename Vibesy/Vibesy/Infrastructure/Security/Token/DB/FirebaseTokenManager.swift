//
//  FirebaseTokenManager.swift
//  Vibesy
//
//  Created by Alexander Cleoni on 1/24/25.
//

import FirebaseFirestore

struct FirebaseTokenManager {
    let firestore = Firestore.firestore()
    
    func saveFCMToken(forUserWithId userId: String, _ tokenId: String) {
        firestore
            .collection("users")
            .document(userId)
            .collection("tokens")
            .document("fcm")
            .setData([
                "fcmToken": tokenId,
                "platform": "iOS",
                "timestamp": Timestamp(date: Date())
            ])
    }
}
