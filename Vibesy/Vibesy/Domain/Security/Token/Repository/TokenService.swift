//
//  TokenService.swift
//  Vibesy
//
//  Created by Alexander Cleoni on 1/24/25.
//

import Foundation

protocol TokenService {
    func saveDeviceRegistrationToken(forUserWithId uid: String, _ token: String)
}
