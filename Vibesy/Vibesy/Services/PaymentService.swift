//
//  PaymentService.swift
//  Vibesy
//
//  Created by Alexander Cleoni on Payment Integration.
//

import Foundation
import Combine
import os.log
import StripePaymentSheet

@MainActor
class PaymentService: ObservableObject {
    static let shared = PaymentService()
    
    private let networkService = EnhancedNetworkService.shared
    private let baseURL = StripeConfig.backendURL
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "Vibesy", category: "PaymentService")
    
    private init() {}
    
    // MARK: - Payment Processing
    
    /// Create real PaymentSheet for UUID events using new backend endpoint
    func createPaymentSheetForEvent(
        event: Event,
        priceDetail: PriceDetails,
        quantity: Int,
        userEmail: String
    ) async throws -> (PaymentSheet, String) {
        
        // Validate inputs
        guard quantity > 0 else {
            throw PaymentError.invalidQuantity
        }
        
        logger.info("Creating real payment intent for UUID event: \(event.id.uuidString)")
        
        // Use the new UUID-compatible endpoint
        guard let url = URL(string: "\(baseURL)/reservation-payments/intent") else {
            throw PaymentError.invalidURL
        }
        
        // Convert Decimal dollar amount to integer cents safely
        let priceDecimal = NSDecimalNumber(decimal: priceDetail.price)
        let roundingBehavior = NSDecimalNumberHandler(
            roundingMode: .plain,
            scale: 0,
            raiseOnExactness: false,
            raiseOnOverflow: false,
            raiseOnUnderflow: false,
            raiseOnDivideByZero: true
        )
        let centsNumber = priceDecimal.multiplying(by: NSDecimalNumber(value: 100), withBehavior: roundingBehavior)
        let priceCents = centsNumber.intValue
        
        let body = [
            "event_id": event.id.uuidString,
            "quantity": quantity,
            "buyer_email": userEmail,
            "buyer_name": userEmail, // Use email as name for now
            "currency": "usd",
            "price_cents": priceCents // Convert Decimal to integer cents
        ] as [String: Any]
        
        do {
            let bodyData = try JSONSerialization.data(withJSONObject: body)
            
            let response: TicketPaymentIntentResponse = try await networkService.post(
                url: url,
                body: bodyData,
                headers: [:],
                responseType: TicketPaymentIntentResponse.self,
                retryConfig: .default
            )
            
            logger.info("Created real payment intent: \(response.paymentIntentClientSecret.prefix(20))...")
            
            // Configure PaymentSheet with real data
            var configuration = PaymentSheet.Configuration()
            configuration.merchantDisplayName = StripeConfig.merchantDisplayName
            
            // Configure Apple Pay
            configuration.applePay = .init(
                merchantId: StripeConfig.merchantId,
                merchantCountryCode: StripeConfig.merchantCountryCode
            )
            
            // Set customer configuration
            configuration.customer = .init(
                id: response.customer,
                ephemeralKeySecret: response.ephemeralKey
            )
            
            // Set return URL for redirects
            configuration.returnURL = StripeConfig.returnURL
            
            // Create PaymentSheet with real client secret
            let paymentSheet = PaymentSheet(
                paymentIntentClientSecret: response.paymentIntentClientSecret,
                configuration: configuration
            )
            
            print("✨ Created REAL PaymentSheet with client secret from backend!")
            return (paymentSheet, "pi_\(response.orderId)")
            
        } catch {
            logger.error("Failed to create real payment intent: \(error.localizedDescription)")
            throw PaymentError.networkError(error)
        }
    }
    
    /// Process payment for event reservation (legacy method for compatibility)
    func processPayment(
        event: Event,
        priceDetail: PriceDetails,
        quantity: Int,
        userEmail: String
    ) async throws -> Bool {
        
        // Validate inputs
        guard quantity > 0 else {
            throw PaymentError.invalidQuantity
        }
        
        guard let stripePriceId = priceDetail.stripePriceId else {
            throw PaymentError.noPriceId
        }
        
        guard let stripeConnectedAccountId = event.stripeConnectedAccountId else {
            throw PaymentError.noConnectedAccount
        }
        
        logger.info("Processing payment for event: \(event.id.uuidString)")
        
        do {
            // Step 1: Create payment intent
            let paymentIntent = try await createPaymentIntent(
                eventId: event.id.uuidString,
                priceId: stripePriceId,
                quantity: quantity,
                userEmail: userEmail,
                connectedAccountId: stripeConnectedAccountId
            )
            
            logger.info("Created payment intent: \(paymentIntent.id)")
            
            // Step 2: Process payment (in a real implementation, this would show the payment sheet)
            // For now, we'll simulate payment processing
            let success = try await simulatePaymentProcessing(paymentIntentId: paymentIntent.id)
            
            if success {
                logger.info("Payment successful for event: \(event.id.uuidString)")
                
                // Step 3: Confirm reservation in Firebase
                try await confirmReservation(
                    eventId: event.id.uuidString,
                    userId: userEmail, // Using email as user identifier for now
                    priceDetailId: priceDetail.id.uuidString,
                    quantity: quantity,
                    paymentIntentId: paymentIntent.id
                )
                
                logger.info("Reservation confirmed for event: \(event.id.uuidString)")
                return true
            } else {
                logger.error("Payment failed for event: \(event.id.uuidString)")
                return false
            }
            
        } catch {
            logger.error("Payment processing error: \(error.localizedDescription)")
            throw error
        }
    }
    
    // MARK: - Private Methods
    
    /// Create payment intent through backend
    private func createPaymentIntent(
        eventId: String,
        priceId: String,
        quantity: Int,
        userEmail: String,
        connectedAccountId: String
    ) async throws -> PaymentIntentResponse {
        
        guard let url = URL(string: "\(baseURL)/stripe/payment-intents") else {
            throw PaymentError.invalidURL
        }
        
        let body = [
            "event_id": eventId,
            "price_id": priceId,
            "quantity": quantity,
            "user_email": userEmail,
            "connected_account_id": connectedAccountId
        ] as [String: Any]
        
        do {
            let bodyData = try JSONSerialization.data(withJSONObject: body)
            
            return try await networkService.post(
                url: url,
                body: bodyData,
                headers: [:],
                responseType: PaymentIntentResponse.self,
                retryConfig: .default
            )
        } catch {
            logger.error("Failed to create payment intent: \(error.localizedDescription)")
            throw PaymentError.networkError(error)
        }
    }
    
    /// Simulate payment processing (replace with actual Stripe payment sheet)
    private func simulatePaymentProcessing(paymentIntentId: String) async throws -> Bool {
        // Simulate network delay
        try await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
        
        // For demonstration purposes, we'll simulate a 90% success rate
        let randomValue = Double.random(in: 0...1)
        return randomValue > 0.1
    }
    
    /// Confirm reservation in Firebase
    private func confirmReservation(
        eventId: String,
        userId: String,
        priceDetailId: String,
        quantity: Int,
        paymentIntentId: String
    ) async throws {
        
        guard let url = URL(string: "\(baseURL)/reservations") else {
            throw PaymentError.invalidURL
        }
        
        let reservation = ReservationRequest(
            eventId: eventId,
            userId: userId,
            priceDetailId: priceDetailId,
            quantity: quantity,
            paymentIntentId: paymentIntentId,
            status: "confirmed",
            createdAt: ISO8601DateFormatter().string(from: Date())
        )
        
        do {
            let bodyData = try JSONEncoder().encode(reservation)
            
            let _: ReservationResponse = try await networkService.post(
                url: url,
                body: bodyData,
                headers: ["Content-Type": "application/json"],
                responseType: ReservationResponse.self,
                retryConfig: .default
            )
            
        } catch {
            logger.error("Failed to confirm reservation: \(error.localizedDescription)")
            throw PaymentError.networkError(error)
        }
    }
}

// MARK: - Error Types

enum PaymentError: LocalizedError {
    case invalidQuantity
    case noPriceId
    case noConnectedAccount
    case invalidURL
    case networkError(Error)
    case paymentFailed
    case reservationFailed
    
    var errorDescription: String? {
        switch self {
        case .invalidQuantity:
            return "Invalid quantity specified"
        case .noPriceId:
            return "Price information not found"
        case .noConnectedAccount:
            return "Event host payment account not configured"
        case .invalidURL:
            return "Invalid service URL"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .paymentFailed:
            return "Payment processing failed"
        case .reservationFailed:
            return "Unable to confirm reservation"
        }
    }
}

// MARK: - Response Models

struct PaymentIntentResponse: Codable {
    let id: String
    let clientSecret: String
    let amount: Int
    let currency: String
    let status: String
    let connectedAccountId: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case clientSecret = "client_secret"
        case amount
        case currency
        case status
        case connectedAccountId = "connected_account_id"
    }
}

struct ReservationRequest: Codable {
    let eventId: String
    let userId: String
    let priceDetailId: String
    let quantity: Int
    let paymentIntentId: String
    let status: String
    let createdAt: String
    
    enum CodingKeys: String, CodingKey {
        case eventId = "event_id"
        case userId = "user_id"
        case priceDetailId = "price_detail_id"
        case quantity
        case paymentIntentId = "payment_intent_id"
        case status
        case createdAt = "created_at"
    }
}

struct ReservationResponse: Codable {
    let id: String
    let eventId: String
    let userId: String
    let status: String
    let createdAt: String
    let updatedAt: String
    
    enum CodingKeys: String, CodingKey {
        case id
        case eventId = "event_id"
        case userId = "user_id"
        case status
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}
