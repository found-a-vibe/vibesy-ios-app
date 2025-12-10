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
    func createPaymentIntent(eventId: Int, quantity: Int, buyerEmail: String, buyerName: String?) async throws -> TicketPaymentIntentResponse {
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
                responseType: TicketPaymentIntentResponse.self,
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
        guard let url = URL(string: "\(baseURL)\(StripeConfig.Endpoints.connectOnboardLink)") else {
            throw APIError.invalidResponse
        }
        
        // Build body with only non-empty optional fields
        var body: [String: Any] = [
            "email": email,
            "return_url": StripeConfig.connectReturnURL,
            "refresh_url": StripeConfig.connectRefreshURL
        ]
        
        // Only include first_name and last_name if they have non-empty values
        if let firstName = firstName, !firstName.isEmpty {
            body["first_name"] = firstName
        }
        if let lastName = lastName, !lastName.isEmpty {
            body["last_name"] = lastName
        }
        
        do {
            let bodyData = try JSONSerialization.data(withJSONObject: body)
            
            logger.info("Creating Connect onboarding link for \(email)")
            
            return try await networkService.post(
                url: url,
                body: bodyData,
                headers: [:],
                responseType: ConnectOnboardingResponse.self,
                retryConfig: .default
            )
        } catch {
            logger.error("Failed to create Connect onboarding link: \(error.localizedDescription)")
            try handleAPIError(error)
            throw error
        }
    }
    
    /// Get Connect account status for a host
    func getConnectStatus(email: String) async throws -> ConnectStatusResponse {
        guard let url = URL(string: "\(baseURL)\(StripeConfig.Endpoints.connectStatus)/\(email)") else {
            throw APIError.invalidResponse
        }
        
        do {
            logger.info("Getting Connect status for \(email)")
            
            return try await networkService.get(
                url: url,
                headers: [:],
                responseType: ConnectStatusResponse.self,
                retryConfig: .default
            )
        } catch {
            logger.error("Failed to get Connect status: \(error.localizedDescription)")
            try handleAPIError(error)
            throw error
        }
    }
    
    // Note: Removed verifyOnboardingComplete method - using getConnectStatus directly for reliability
    
    /// Disconnect Stripe Connect account
    func disconnectStripe(email: String) async throws {
        guard let url = URL(string: "\(baseURL)\(StripeConfig.Endpoints.connectDisconnect)") else {
            throw APIError.invalidResponse
        }
        
        let body = ["email": email]
        
        do {
            let bodyData = try JSONSerialization.data(withJSONObject: body)
            
            logger.info("Disconnecting Stripe for \(email)")
            
            let _: EmptyResponse = try await networkService.post(
                url: url,
                body: bodyData,
                headers: [:],
                responseType: EmptyResponse.self,
                retryConfig: .default
            )
        } catch {
            logger.error("Failed to disconnect Stripe: \(error.localizedDescription)")
            try handleAPIError(error)
            throw error
        }
    }
    
    /// Get Stripe Connect dashboard link for host
    func getConnectDashboardLink(email: String, accountId: String) async throws -> ConnectDashboardResponse {
        guard let url = URL(string: "\(baseURL)\(StripeConfig.Endpoints.connectDashboard)") else {
            throw APIError.invalidResponse
        }
        
        let body = [
            "email": email,
            "account_id": accountId
        ]
        
        do {
            let bodyData = try JSONSerialization.data(withJSONObject: body)
            
            logger.info("Getting Connect dashboard link for \(email)")
            
            return try await networkService.post(
                url: url,
                body: bodyData,
                headers: [:],
                responseType: ConnectDashboardResponse.self,
                retryConfig: .default
            )
        } catch {
            logger.error("Failed to get Connect dashboard link: \(error.localizedDescription)")
            try handleAPIError(error)
            throw error
        }
    }
    
    // MARK: - Ticket Methods
    
    /// Get tickets for an order
    func getOrderTickets(orderId: Int) async throws -> OrderTicketsResponse {
        guard let url = URL(string: "\(baseURL)\(StripeConfig.Endpoints.orderTickets)/\(orderId)") else {
            throw APIError.invalidResponse
        }
        
        do {
            logger.info("Getting tickets for order \(orderId)")
            
            return try await networkService.get(
                url: url,
                headers: [:],
                responseType: OrderTicketsResponse.self,
                retryConfig: .default
            )
        } catch {
            logger.error("Failed to get order tickets: \(error.localizedDescription)")
            try handleAPIError(error)
            throw error
        }
    }
    
    /// Verify a ticket by QR token
    func verifyTicket(token: String) async throws -> TicketVerificationResponse {
        guard let url = URL(string: "\(baseURL)\(StripeConfig.Endpoints.ticketVerify)?token=\(token)") else {
            throw APIError.invalidResponse
        }
        
        do {
            logger.info("Verifying ticket with token")
            
            return try await networkService.get(
                url: url,
                headers: [:],
                responseType: TicketVerificationResponse.self,
                retryConfig: .default
            )
        } catch {
            logger.error("Failed to verify ticket: \(error.localizedDescription)")
            try handleAPIError(error)
            throw error
        }
    }
    
    // MARK: - Invoice Methods
    
    /// Get invoice details for a payment intent
    func getInvoiceDetails(paymentIntentId: String) async throws -> InvoiceResponse {
        guard !paymentIntentId.isEmpty else {
            logger.error("Empty payment intent ID provided")
            throw APIError.invalidResponse
        }
        
        guard let url = URL(string: "\(baseURL)\(StripeConfig.Endpoints.invoiceDetails)/\(paymentIntentId)") else {
            logger.error("Failed to construct invoice URL for payment intent: \(paymentIntentId)")
            throw APIError.invalidResponse
        }
        
        do {
            logger.info("Getting invoice details for payment intent: \(paymentIntentId)")
            
            let response = try await networkService.get(
                url: url,
                headers: ["Content-Type": "application/json"],
                responseType: InvoiceResponse.self,
                retryConfig: .default
            )
            
            logger.info("Successfully retrieved invoice details for: \(paymentIntentId)")
            return response
        } catch {
            logger.error("Failed to get invoice details for \(paymentIntentId): \(error.localizedDescription)")
            try handleAPIError(error)
            throw error
        }
    }
    
    /// Get payment receipt for a payment intent
    func getPaymentReceipt(paymentIntentId: String) async throws -> PaymentReceiptResponse {
        guard !paymentIntentId.isEmpty else {
            logger.error("Empty payment intent ID provided for receipt")
            throw APIError.invalidResponse
        }
        
        guard let url = URL(string: "\(baseURL)\(StripeConfig.Endpoints.paymentReceipt)/\(paymentIntentId)") else {
            logger.error("Failed to construct receipt URL for payment intent: \(paymentIntentId)")
            throw APIError.invalidResponse
        }
        
        do {
            logger.info("Getting payment receipt for payment intent: \(paymentIntentId)")
            
            let response = try await networkService.get(
                url: url,
                headers: ["Content-Type": "application/json"],
                responseType: PaymentReceiptResponse.self,
                retryConfig: .default
            )
            
            logger.info("Successfully retrieved payment receipt for: \(paymentIntentId)")
            return response
        } catch {
            logger.error("Failed to get payment receipt for \(paymentIntentId): \(error.localizedDescription)")
            try handleAPIError(error)
            throw error
        }
    }
    
    /// Get QR code data with invoice information for a ticket
    func getTicketQRWithInvoice(ticketId: Int) async throws -> QRInvoiceData {
        guard ticketId > 0 else {
            logger.error("Invalid ticket ID provided: \(ticketId)")
            throw APIError.invalidResponse
        }
        
        guard let url = URL(string: "\(baseURL)\(StripeConfig.Endpoints.ticketQR)/\(ticketId)/invoice") else {
            logger.error("Failed to construct QR invoice URL for ticket: \(ticketId)")
            throw APIError.invalidResponse
        }
        
        do {
            logger.info("Getting QR invoice data for ticket: \(ticketId)")
            
            let response = try await networkService.get(
                url: url,
                headers: ["Content-Type": "application/json"],
                responseType: QRInvoiceData.self,
                retryConfig: .default
            )
            
            logger.info("Successfully retrieved QR invoice data for ticket: \(ticketId)")
            return response
        } catch {
            logger.error("Failed to get QR invoice data for ticket \(ticketId): \(error.localizedDescription)")
            try handleAPIError(error)
            throw error
        }
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

// MARK: - Empty Response Model

struct EmptyResponse: Codable {
    // Empty struct for void API responses
}
