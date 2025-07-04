//
//  AuthenticationService.swift
//  Vibesy
//
//  Created by Alexander Cleoni on 12/14/24.
//

import Combine

protocol AuthenticationService {
    func signIn(email: String, password: String) -> Future<AuthUser?, Error>
    func signUp(email: String, password: String) -> Future<AuthUser?, Error>
    func signOut() -> Future<Void, Never>
}
