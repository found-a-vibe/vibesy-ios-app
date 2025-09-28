//
//  AuthenticationModel.swift
//  Vibesy
//
//  Created by Alexander Cleoni on 12/14/24.
//
import Foundation
import Combine
import FirebaseAuth
import FirebaseFunctions
import StreamChat
import StreamChatSwiftUI

enum AuthenticationStatus {
    case loggedIn
    case loggedOut
    case loginError
}

enum SettingsAlert: Identifiable {
    case wrongPassword
    case passwordMismatch
    case passwordUpdated
    
    var id: Int {
        hashValue
    }
    
    var title: String {
        switch self {
        case .wrongPassword: return "User Authentication Failed."
        case .passwordMismatch: return "Passwords Do Not Match."
        case .passwordUpdated: return "Password Updated."
        }
    }
    
    var message: String {
        switch self {
        case .wrongPassword: return "The current password is incorrect. Please try again."
        case .passwordMismatch: return "Please confirm that your passwords match and try again."
        case .passwordUpdated: return "Your password has been updated successfully."
        }
    }
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

@MainActor
final class AuthenticationModel: ObservableObject {
    @Injected(\.chatClient) var chatClient
    
    @Published var state = AppState()
    @Published var email: String = ""
    @Published var password: String = ""
    @Published var authenticationStatus: AuthenticationStatus?
    @Published var authError: String?  // Stores authentication errors
    @Published var handler: AuthStateDidChangeListenerHandle?
    
    @Published var reauthenticationError: Bool = false {
        didSet {
            if reauthenticationError {
                activeAlert = .wrongPassword
            }
        }
    }
    
    @Published var activeAlert: SettingsAlert?
    
    private var cancellableBag = Set<AnyCancellable>()
    private let authenticationService: AuthenticationService
    private lazy var functions = Functions.functions()
    
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
    
    func updateCurrentUserPassword(email: String, password: String, newPassword: String) {
        authenticationService.updateCurrentUserPassword(email: email, password: password, newPassword: newPassword)
            .receive(on: RunLoop.main)
            .sink(receiveCompletion: { completion in
                if case .failure(let error) = completion {
                    self.authError = error.localizedDescription
                    self.reauthenticationError = true
                }
            }, receiveValue: { _ in
                self.authError = nil
                self.reauthenticationError = false
                self.activeAlert = .passwordUpdated
            })
            .store(in: &cancellableBag)
    }
    
    func deleteCurrentUser(email: String, password: String) {
        authenticationService.deleteCurrentUser(email: email, password: password)
            .receive(on: RunLoop.main)
            .sink(receiveCompletion: { completion in
                if case .failure(let error) = completion {
                    self.authError = error.localizedDescription
                    self.reauthenticationError = true
                }
            }, receiveValue: { _ in
                self.authError = nil
                self.state.currentUser = nil
                self.authenticationStatus = .loggedOut
                self.reauthenticationError = false
            })
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
    
    func connectUser(username: String, photoUrl: String) {
        functions.httpsCallable("ext-auth-chat-getStreamUserToken").call { (result, error) in
            if let error = error as NSError? {
                if error.domain == FunctionsErrorDomain {
                    let code = FunctionsErrorCode(rawValue: error.code)
                    let message = error.localizedDescription
                    let details = error.userInfo[FunctionsErrorDetailsKey]
                    print("Error calling Cloud Function: \(code ?? .unknown), Message: \(message), Details: \(details ?? "N/A")")
                }
                return
            }
            if let streamToken = result?.data as? String, let id = self.state.currentUser?.id  {
                print("Received Stream User Token.")
                // Use the streamToken to initialize Stream Chat SDK
                self.chatClient.connectUser(
                    userInfo: .init(id: id, name: username, imageURL: URL(string: photoUrl)),
                    token: try! Token(rawValue: streamToken)
                )
            } else {
                print("Failed to retrieve Stream User Token from result.")
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
