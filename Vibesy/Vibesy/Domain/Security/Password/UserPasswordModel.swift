//
//  UserPasswordModel.swift
//  Vibesy
//
//  Created by Alexander Cleoni on 6/5/25.
//

import Foundation

@MainActor
class UserPasswordModel: ObservableObject {
    var email: String?
    var uid: String?
    
    private let service: UserPasswordService
    
    
    init(service: UserPasswordService) {
        self.service = service
    }
    
    func sendOTP(for email: String, completion: @escaping @Sendable (Result<UserPasswordServiceResponse, Error>) -> Void) {
        service.sendOTP(to: email) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let statusResponse):
                    let returnedUID = statusResponse.data?.uid
                    self.uid = returnedUID
                    self.email = email
                    completion(.success(statusResponse))
                case .failure(let error):
                    completion(.failure(error))
                }
            }
        }
    }
    
    func verifyOTP(with otp: String, completion: @escaping @Sendable (Result<UserPasswordServiceResponse, Error>) -> Void) {
        guard let email = email else {
            let error = NSError(
                domain: "com.foundavibe.verifyOTP",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "No email available to verify OTP."]
            )
            completion(.failure(error))
            return
        }
        
        service.verifyOTP(for: email, withOTP: otp) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let statusResponse):
                    let returnedUID = statusResponse.data?.uid
                    self.uid = returnedUID
                    completion(.success(statusResponse))
                case .failure(let error):
                    completion(.failure(error))
                }
            }
        }
    }
    
    func updatePassword(withNewPassword newPassword: String, completion: @escaping @Sendable (Result<UserPasswordServiceResponse, Error>) -> Void) {
        guard let uid = uid else {
            let error = NSError(
                domain: "com.foundavibe.updatePassword",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "No uid available to updated password."]
            )
            completion(.failure(error))
            return
        }
        
        service.updatePassword(for: uid, withNewPassword: newPassword) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let statusResponse):
                    completion(.success(statusResponse))
                case .failure(let error):
                    completion(.failure(error))
                }
            }
        }
    }
}
