//
//  FirebaseTokenService.swift
//  Vibesy
//
//  Created by Alexander Cleoni on 1/24/25.
//

import Foundation

struct FirebaseTokenService: TokenService {
    private let tokenManager = FirebaseTokenManager()
    
    func saveDeviceRegistrationToken(forUserWithId uid: String, _ token: String) {
        tokenManager.saveFCMToken(forUserWithId: uid, token)
    }
}
