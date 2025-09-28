//
//  VibesyUserPasswordService.swift
//  Vibesy
//
//  Created by Alexander Cleoni on 6/5/25.
//

import Foundation
import os.log

struct UserMetadata: Codable {
    var uid: String
    var email: String
}

struct UserPasswordServiceResponse: Codable {
    var status: String
    var description: String
    var data: UserMetadata?
}

// MARK: - Enhanced Password Service with Security
struct VibesyUserPasswordService: UserPasswordService {
    private static let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "Vibesy", category: "PasswordService")
    
    private let baseURL: String = "https://one-time-password-service.onrender.com"
    
    private var securityService: EnhancedSecurityService {
        get async {
            await EnhancedSecurityService.shared
        }
    }
    
    // MARK: - Configuration
    private let timeoutInterval: TimeInterval = 30.0
    private let maxRetryAttempts = 3
    
    // MARK: - Send OTP with Security
    public func sendOTP(to email: String, completion: @escaping @Sendable (Result<UserPasswordServiceResponse, Error>) -> Void) {
        Task {
            do {
                let result = try await sendOTPAsync(to: email)
                await MainActor.run {
                    completion(.success(result))
                }
            } catch {
                await MainActor.run {
                    completion(.failure(error))
                }
            }
        }
    }
    
    private func sendOTPAsync(to email: String) async throws -> UserPasswordServiceResponse {
        let service = await securityService
        
        // Validate email format
        guard await service.validateEmail(email) else {
            Self.logger.error("Invalid email format: \(email)")
            throw SecurityError.invalidPassword
        }
        
        // Rate limiting
        try await service.checkRateLimit(for: "otp_\(email)")
        
        // Sanitize input
        let sanitizedEmail = await service.sanitizeInput(email)
        
        guard let url = URL(string: "\(baseURL)/otp/send") else {
            throw URLError(.badURL)
        }
        
        var request = await service.createSecureURLRequest(url: url)
        request.httpMethod = "POST"
        
        let body = ["email": sanitizedEmail]
        
        do {
            request.httpBody = try JSONEncoder().encode(body)
        } catch {
            Self.logger.error("Failed to encode request body: \(error.localizedDescription)")
            throw error
        }
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        // Validate HTTP response
        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        
        guard 200...299 ~= httpResponse.statusCode else {
            Self.logger.error("HTTP error: \(httpResponse.statusCode)")
            throw URLError(.badServerResponse)
        }
        
        do {
            let decodedResponse = try JSONDecoder().decode(UserPasswordServiceResponse.self, from: data)
            Self.logger.info("OTP sent successfully to \(sanitizedEmail)")
            return decodedResponse
        } catch {
            Self.logger.error("Failed to decode response: \(error.localizedDescription)")
            throw error
        }
    }
    // MARK: - Verify OTP with Security
    public func verifyOTP(for email: String, withOTP otp: String, completion: @escaping @Sendable (Result<UserPasswordServiceResponse, Error>) -> Void) {
        Task {
            do {
                let result = try await verifyOTPAsync(for: email, withOTP: otp)
                await MainActor.run {
                    completion(.success(result))
                }
            } catch {
                await MainActor.run {
                    completion(.failure(error))
                }
            }
        }
    }
    
    private func verifyOTPAsync(for email: String, withOTP otp: String) async throws -> UserPasswordServiceResponse {
        let service = await securityService
        
        // Validate inputs
        guard await service.validateEmail(email) else {
            Self.logger.error("Invalid email format for OTP verification")
            throw SecurityError.invalidPassword
        }
        
        guard otp.count == 6, otp.allSatisfy(\.isNumber) else {
            Self.logger.error("Invalid OTP format")
            throw SecurityError.invalidPassword
        }
        
        // Rate limiting
        try await service.checkRateLimit(for: "verify_\(email)")
        
        // Sanitize inputs
        let sanitizedEmail = await service.sanitizeInput(email)
        let sanitizedOTP = await service.sanitizeInput(otp)
        
        guard let url = URL(string: "\(baseURL)/otp/verify") else {
            throw URLError(.badURL)
        }
        
        var request = await service.createSecureURLRequest(url: url)
        request.httpMethod = "POST"
        
        let body = ["email": sanitizedEmail, "otp": sanitizedOTP]
        
        do {
            request.httpBody = try JSONEncoder().encode(body)
        } catch {
            Self.logger.error("Failed to encode OTP verification request: \(error.localizedDescription)")
            throw error
        }
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        // Validate response
        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        
        guard 200...299 ~= httpResponse.statusCode else {
            Self.logger.error("OTP verification failed with status: \(httpResponse.statusCode)")
            throw URLError(.badServerResponse)
        }
        
        do {
            let decodedResponse = try JSONDecoder().decode(UserPasswordServiceResponse.self, from: data)
            Self.logger.info("OTP verified successfully for \(sanitizedEmail)")
            return decodedResponse
        } catch {
            Self.logger.error("Failed to decode OTP verification response: \(error.localizedDescription)")
            throw error
        }
    }
    
    // MARK: - Update Password with Security
    public func updatePassword(for uid: String, withNewPassword newPassword: String, completion: @escaping @Sendable (Result<UserPasswordServiceResponse, Error>) -> Void) {
        Task {
            do {
                let result = try await updatePasswordAsync(for: uid, withNewPassword: newPassword)
                await MainActor.run {
                    completion(.success(result))
                }
            } catch {
                await MainActor.run {
                    completion(.failure(error))
                }
            }
        }
    }
    
    private func updatePasswordAsync(for uid: String, withNewPassword newPassword: String) async throws -> UserPasswordServiceResponse {
        let service = await securityService
        
        // Validate UID
        guard !uid.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            Self.logger.error("Invalid UID for password update")
            throw SecurityError.invalidPassword
        }
        
        // Validate password strength
        try await service.validatePassword(newPassword)
        
        // Rate limiting
        try await service.checkRateLimit(for: "password_\(uid)")
        
        // Sanitize inputs
        let sanitizedUID = await service.sanitizeInput(uid)
        
        guard let url = URL(string: "\(baseURL)/password/reset") else {
            throw URLError(.badURL)
        }
        
        var request = await service.createSecureURLRequest(url: url)
        request.httpMethod = "POST"
        
        // Hash the password before sending (additional security layer)
        let hashedPassword = await service.hashSensitiveData(newPassword)
        
        let body = ["uid": sanitizedUID, "password": hashedPassword]
        
        do {
            request.httpBody = try JSONEncoder().encode(body)
        } catch {
            Self.logger.error("Failed to encode password update request: \(error.localizedDescription)")
            throw error
        }
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        // Validate response
        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        
        guard 200...299 ~= httpResponse.statusCode else {
            Self.logger.error("Password update failed with status: \(httpResponse.statusCode)")
            throw URLError(.badServerResponse)
        }
        
        do {
            let decodedResponse = try JSONDecoder().decode(UserPasswordServiceResponse.self, from: data)
            Self.logger.info("Password updated successfully for user: \(sanitizedUID)")
            return decodedResponse
        } catch {
            Self.logger.error("Failed to decode password update response: \(error.localizedDescription)")
            throw error
        }
    }
}
