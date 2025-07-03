//
//  FirebaseAuthenticationService.swift
//  Vibesy
//
//  Created by Alexander Cleoni on 11/22/24.
//

import Combine
import FirebaseAuth

struct FirebaseAuthenticationService: AuthenticationService {
    func signIn(email: String, password: String) -> Future<AuthUser?, Error> {
        return Future<AuthUser?, Error> { promise in
            Auth.auth().signIn(withEmail: email, password: password) { authResult, error in
                if let error = error {
                    promise(.failure(error)) // Return Firebase error
                    return
                }
                
                guard let id = authResult?.user.uid,
                      let email = authResult?.user.email else {
                    promise(.success(nil)) // Return nil if authentication succeeds but user data is missing
                    return
                }
                
                let user = AuthUser(id: id, email: email, isNewUser: false)
                promise(.success(user))
            }
        }
    }

    func signUp(email: String, password: String) -> Future<AuthUser?, Error> {
        return Future<AuthUser?, Error> { promise in
            Auth.auth().createUser(withEmail: email, password: password) { authResult, error in
                if let error = error {
                    promise(.failure(error)) // Return Firebase error
                    return
                }
                
                guard let id = authResult?.user.uid,
                      let email = authResult?.user.email else {
                    promise(.success(nil)) // Return nil if authentication succeeds but user data is missing
                    return
                }
                
                let user = AuthUser(id: id, email: email, isNewUser: true)
                promise(.success(user))
            }
        }
    }
    
    func signOut() -> Future<Void, Never> {
        Future<Void, Never> { promise in
            do {
                try Auth.auth().signOut()
                promise(.success(()))
            } catch {
                print("Sign out error: \(error.localizedDescription)")
                promise(.success(()))
            }
        }
    }
}
