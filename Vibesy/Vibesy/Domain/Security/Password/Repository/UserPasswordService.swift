//
//  UserPasswordService.swift
//  Vibesy
//
//  Created by Alexander Cleoni on 6/5/25.
//

protocol UserPasswordService {
    func sendOTP(to email: String, completion: @escaping (Result<UserPasswordServiceResponse, Error>) -> Void)
    func verifyOTP(for email: String, withOTP otp: String, completion: @escaping (Result<UserPasswordServiceResponse, Error>) -> Void)
    func updatePassword(for uid: String, withNewPassword newPassword: String, completion: @escaping (Result<UserPasswordServiceResponse, Error>) -> Void)
}
