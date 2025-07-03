//
//  AuthenticationModel.swift
//  Vibesy
//
//  Created by Alexander Cleoni on 12/14/24.
//
import Foundation
import Combine
import FirebaseAuth

enum AuthenticationStatus {
    case loggedIn
    case loggedOut
    case loginError
}

// Struct user
struct AuthUser: Equatable {
    let id: String
    let email: String
    var isNewUser: Bool
}

// App state must be a struct too
struct AppState: Equatable {
    var currentUser: AuthUser?
}

final class AuthenticationModel: ObservableObject {
    @Published var state = AppState()
    @Published var email: String = ""
    @Published var password: String = ""
    @Published var authenticationStatus: AuthenticationStatus?
    @Published var authError: String?  // Stores authentication errors
    @Published var handler: AuthStateDidChangeListenerHandle?
    
    private var cancellableBag = Set<AnyCancellable>()
    private let authenticationService: AuthenticationService
    
    init(authenticationService: AuthenticationService, state: AppState) {
        self.authenticationService = authenticationService
        self.state = state
        if UserDefaults.standard.bool(forKey: "rememberMe") == true {
            self.setAuthHandler()
        }
    }
    
    func signUp() {
        authenticationService.signUp(email: email, password: password)
            .receive(on: RunLoop.main)
            .sink(receiveCompletion: { completion in
                if case .failure(let error) = completion {
                    self.authError = error.localizedDescription
                    self.authenticationStatus = .loginError
                }
            }, receiveValue: { user in
                self.authenticationStatus = self.resultMapper(with: user)
            })
            .store(in: &cancellableBag)
    }
    
    func signIn() {
        authenticationService.signIn(email: email, password: password)
            .receive(on: RunLoop.main)
            .sink(receiveCompletion: { completion in
                if case .failure(let error) = completion {
                    self.authError = error.localizedDescription
                    self.authenticationStatus = .loginError
                }
            }, receiveValue: { user in
                self.authenticationStatus = self.resultMapper(with: user)
            })
            .store(in: &cancellableBag)
    }
    
    func signOut() {
        authenticationService.signOut()
            .sink {
                DispatchQueue.main.async {
                    self.state.currentUser = nil
                    self.authenticationStatus = .loggedOut
                }
            }
            .store(in: &cancellableBag)
    }
    
    private func setAuthHandler() {
        handler = Auth.auth().addStateDidChangeListener { [weak self] res, user in
            guard let self = self else { return }
            if let uid = user?.uid, let email = user?.email {
                self.state.currentUser = AuthUser(id: uid, email: email, isNewUser: false)
                self.authenticationStatus = .loggedIn
            } else {
                self.authenticationStatus = .loggedOut
            }
        }
    }
}

extension AuthenticationModel {
    private func resultMapper(with user: AuthUser?) -> AuthenticationStatus {
        if let user = user {
            state.currentUser = user
            self.email = ""
            self.password = ""
            return .loggedIn
        } else {
            return .loggedOut
        }
    }
}

extension AppState {
    static func == (lhs: AppState, rhs: AppState) -> Bool {
        return lhs.currentUser == rhs.currentUser
    }
}
