//
//  VibesyUserPasswordService.swift
//  Vibesy
//
//  Created by Alexander Cleoni on 6/5/25.
//

import Foundation

struct UserMetadata: Codable {
    var uid: String
    var email: String
}

struct UserPasswordServiceResponse: Codable {
    var status: String
    var description: String
    var data: UserMetadata?
}

struct VibesyUserPasswordService: UserPasswordService {
    let baseURL: String = "https://one-time-password-service.onrender.com"
//    let baseURL: String = "http://10.20.226.2:3000"
    
    public func sendOTP(to email: String, completion: @escaping (Result<UserPasswordServiceResponse, Error>) -> Void) {
        let endpoint = URL(string: "\(baseURL)/otp/send")
        var request = URLRequest(url: endpoint!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: String] = ["email": email]
        let jsonBody = try! JSONEncoder().encode(body)
        request.httpBody = jsonBody
        
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            guard let data else { return }
            
            do {
                let response = try JSONDecoder().decode(UserPasswordServiceResponse.self, from: data)
                completion(.success(response))
            } catch {
                completion(.failure(error))
            }
        }
        task.resume()
    }
    
    public func verifyOTP(for email: String, withOTP otp: String, completion: @escaping (Result<UserPasswordServiceResponse, Error>) -> Void) {
        let endpoint = URL(string: "\(baseURL)/otp/verify")
        var request = URLRequest(url: endpoint!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: String] = ["email": email, "otp": otp]
        let jsonBody = try! JSONEncoder().encode(body)
        request.httpBody = jsonBody
        
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            guard let data else { return }
            
            do {
                let response = try JSONDecoder().decode(UserPasswordServiceResponse.self, from: data)
                completion(.success(response))
            } catch {
                completion(.failure(error))
            }
        }
        task.resume()
    }
    
    public func updatePassword(for uid: String, withNewPassword newPassword: String, completion: @escaping (Result<UserPasswordServiceResponse, Error>) -> Void) {
        let endpoint = URL(string: "\(baseURL)/password/reset")
        var request = URLRequest(url: endpoint!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: String] = ["uid": uid, "password": newPassword]
        let jsonBody = try! JSONEncoder().encode(body)
        request.httpBody = jsonBody
        
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            guard let data else { return }
            
            do {
                let response = try JSONDecoder().decode(UserPasswordServiceResponse.self, from: data)
                completion(.success(response))
            } catch {
                completion(.failure(error))
            }
        }
        task.resume()
    }
}
