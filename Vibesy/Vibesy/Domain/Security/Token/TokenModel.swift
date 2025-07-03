//
//  TokenModel.swift
//  Vibesy
//
//  Created by Alexander Cleoni on 1/24/25.
//

import Foundation

class TokenModel {
    private let service: TokenService
    
    init (service: TokenService) {
        self.service = service
    }
    
    func saveDeviceRegistrationToken(forUserWithId uid: String, _ token: String) {
        service.saveDeviceRegistrationToken(forUserWithId: uid, token)
    }
}
