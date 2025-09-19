//
//  StripeAPIService.swift
//  Vibesy
//
//  Created by Alexander Cleoni on Payment Integration.
//

import Foundation
import Combine
import os.log

@MainActor
class StripeAPIService: ObservableObject {
    static let shared = StripeAPIService()
    
    private let networkService = EnhancedNetworkService.shared
    private let baseURL = StripeConfig.backendURL
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "Vibesy", category: "StripeAPIService")
    
    private init() {}
    
    // MARK: - Error Handling
    private func handleAPIError(_ error: Error) throws {
        if let networkError = error as? NetworkError {
            switch networkError {
            case .authenticationRequired:
                throw APIError.serverError("Authentication required")
            case .forbidden:
                throw APIError.serverError("Access forbidden")
            case .notFound:
                throw APIError.serverError("Resource not found")
            case .tooManyRequests:
                throw APIError.serverError("Rate limit exceeded")
            case .noConnection:
                throw APIError.networkError(error)
            default:
                throw APIError.networkError(error)
            }
        }
        throw APIError.networkError(error)
    }
    
    // MARK: - Payment Methods
    
    /// Create a payment intent for ticket purchase
    func createPaymentIntent(eventId: Int, quantity: Int, buyerEmail: String, buyerName: String?) async throws -> PaymentIntentResponse {
        guard let url = URL(string: "\(baseURL)\(StripeConfig.Endpoints.paymentIntent)") else {
            throw APIError.invalidResponse
        }
        
        let body = [
            "event_id": eventId,
            "quantity": quantity,
            "buyer_email": buyerEmail,
            "buyer_name": buyerName ?? "",
            "currency": StripeConfig.currency
        ] as [String: Any]
        
        do {
            let bodyData = try JSONSerialization.data(withJSONObject: body)
            
            logger.info("Creating payment intent for event \(eventId)")
            
            return try await networkService.post(
                url: url,
                body: bodyData,
                headers: [:],
                responseType: PaymentIntentResponse.self,
                retryConfig: .default
            )
        } catch {
            logger.error("Failed to create payment intent: \(error.localizedDescription)")
            try handleAPIError(error)
            throw error
        }
    }
    
    /// Get payment configuration
    func getPaymentConfig() async throws -> PaymentConfigResponse {
        guard let url = URL(string: "\(baseURL)\(StripeConfig.Endpoints.paymentConfig)") else {
            throw APIError.invalidResponse
        }
        
        do {
            logger.info("Getting payment configuration")
            
            return try await networkService.get(
                url: url,
                headers: [:],
                responseType: PaymentConfigResponse.self,
                retryConfig: .default
            )
        } catch {
            logger.error("Failed to get payment config: \(error.localizedDescription)")
            try handleAPIError(error)
            throw error
        }
    }
    
    // MARK: - Connect Methods
    
    /// Create Connect onboarding link for hosts
    func createConnectOnboardingLink(email: String, firstName: String?, lastName: String?) async throws -> ConnectOnboardingResponse {
        let url = URL(string: "\(baseURL)\(StripeConfig.Endpoints.connectOnboardLink)")!
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body = [
            "email": email,
            "first_name": firstName ?? "",
            "last_name": lastName ?? "",
            "return_url": StripeConfig.connectReturnURL,
            "refresh_url": StripeConfig.connectRefreshURL
        ] as [String: Any]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        if httpResponse.statusCode >= 400 {
            let errorResponse = try? JSONDecoder().decode(APIErrorResponse.self, from: data)
            throw APIError.serverError(errorResponse?.error.message ?? "Unknown error")
        }
        
        return try JSONDecoder().decode(ConnectOnboardingResponse.self, from: data)
    }
    
    /// Get Connect account status for a host
    func getConnectStatus(email: String) async throws -> ConnectStatusResponse {
        let url = URL(string: "\(baseURL)\(StripeConfig.Endpoints.connectStatus)/\(email)")!
        
        let (data, response) = try await session.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        if httpResponse.statusCode >= 400 {
            let errorResponse = try? JSONDecoder().decode(APIErrorResponse.self, from: data)
            throw APIError.serverError(errorResponse?.error.message ?? "User not found")
        }
        
        return try JSONDecoder().decode(ConnectStatusResponse.self, from: data)
    }
    
    /// Disconnect Stripe Connect account
    func disconnectStripe(email: String) async throws {
        let url = URL(string: "\(baseURL)\(StripeConfig.Endpoints.connectDisconnect)")!
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body = ["email": email]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        if httpResponse.statusCode >= 400 {
            let errorResponse = try? JSONDecoder().decode(APIErrorResponse.self, from: data)
            throw APIError.serverError(errorResponse?.error.message ?? "Disconnect failed")
        }
    }
    
    // MARK: - Ticket Methods
    
    /// Get tickets for an order
    func getOrderTickets(orderId: Int) async throws -> OrderTicketsResponse {
        let url = URL(string: "\(baseURL)\(StripeConfig.Endpoints.orderTickets)/\(orderId)")!
        
        let (data, response) = try await session.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        if httpResponse.statusCode >= 400 {
            let errorResponse = try? JSONDecoder().decode(APIErrorResponse.self, from: data)
            throw APIError.serverError(errorResponse?.error.message ?? "Order not found")
        }
        
        return try JSONDecoder().decode(OrderTicketsResponse.self, from: data)
    }
    
    /// Verify a ticket by QR token
    func verifyTicket(token: String) async throws -> TicketVerificationResponse {
        let url = URL(string: "\(baseURL)\(StripeConfig.Endpoints.ticketVerify)?token=\(token)")!
        
        let (data, response) = try await session.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        if httpResponse.statusCode >= 400 {
            let errorResponse = try? JSONDecoder().decode(APIErrorResponse.self, from: data)
            throw APIError.serverError(errorResponse?.error.message ?? "Invalid ticket")
        }
        
        return try JSONDecoder().decode(TicketVerificationResponse.self, from: data)
    }
}

// MARK: - Additional Response Models

struct PaymentConfigResponse: Codable {
    let publishableKey: String
    let currency: String
    let country: String
}

struct TicketVerificationResponse: Codable {
    let valid: Bool
    let used: Bool?
    let eventAccessible: Bool?
    let ticket: TicketDetail?
    let event: EventDetail?
    let error: APIErrorDetail?
    
    enum CodingKeys: String, CodingKey {
        case valid, used, error, ticket, event
        case eventAccessible = "event_accessible"
    }
}

struct TicketDetail: Codable {
    let id: Int
    let ticketNumber: String
    let status: String
    let holderName: String?
    let holderEmail: String?
    let scannedAt: String?
    
    enum CodingKeys: String, CodingKey {
        case id, status
        case ticketNumber = "ticket_number"
        case holderName = "holder_name"
        case holderEmail = "holder_email"
        case scannedAt = "scanned_at"
    }
}

struct EventDetail: Codable {
    let id: Int
    let title: String
    let venue: String
    let startsAt: String
    
    enum CodingKeys: String, CodingKey {
        case id, title, venue
        case startsAt = "starts_at"
    }
}

// MARK: - Error Models

struct APIErrorResponse: Codable {
    let error: APIErrorDetail
}

struct APIErrorDetail: Codable {
    let message: String
}

enum APIError: LocalizedError {
    case invalidResponse
    case serverError(String)
    case networkError(Error)
    
    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid response from server"
        case .serverError(let message):
            return message
        case .networkError(let error):
            return error.localizedDescription
        }
    }
}