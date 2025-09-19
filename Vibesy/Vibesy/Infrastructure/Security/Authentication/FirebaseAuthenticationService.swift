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
    
    func updateCurrentUserPassword(email: String, password: String, newPassword: String) -> Future<Void, Error> {
        return Future { promise in
            guard let user = Auth.auth().currentUser else {
                print("No logged-in user to update password.")
                return promise(.success(()))
            }

            let credential = EmailAuthProvider.credential(withEmail: email, password: password)

            // 1) Re-authenticate
            user.reauthenticate(with: credential) { _, authError in
                if let authError = authError {
                    print("Re-authentication failed:", authError.localizedDescription)
                    return promise(.failure((authError)))
                }

                // 2) Updated now that we’re “recently authenticated”
                user.updatePassword(to: newPassword) { updateError in
                    if let updateError = updateError {
                        print("User password update failed:", updateError.localizedDescription)
                    } else {
                        print("User password updated.")
                    }
                    promise(.success(()))
                }
            }
        }
    }
    
    func deleteCurrentUser(email: String, password: String) -> Future<Void, Error> {
        return Future { promise in
            guard let user = Auth.auth().currentUser else {
                print("No logged-in user to delete.")
                return promise(.success(()))
            }

            let credential = EmailAuthProvider.credential(withEmail: email, password: password)

            // 1) Re-authenticate
            user.reauthenticate(with: credential) { _, authError in
                if let authError = authError {
                    print("Re-authentication failed:", authError.localizedDescription)
                    return promise(.failure((authError)))
                }

                // 2) Delete now that we’re “recently authenticated”
                user.delete { deleteError in
                    if let deleteError = deleteError {
                        print("Account deletion failed:", deleteError.localizedDescription)
                    } else {
                        print("Account deleted.")
                    }
                    promise(.success(()))
                }
            }
        }
    }
}
