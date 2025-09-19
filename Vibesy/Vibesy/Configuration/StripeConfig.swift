//
//  StripeConfig.swift
//  Vibesy
//
//  Created by Alexander Cleoni on Payment Integration.
//

import Foundation

struct StripeConfig {
    // MARK: - Stripe Configuration
    static let publishableKey = "pk_test_your_stripe_publishable_key_here" // Replace with your actual key
    static let merchantId = "merchant.com.foundavibe.vibesy" // Replace with your Apple Pay merchant ID
    static let merchantCountryCode = "US"
    static let currency = "usd"
    
    // MARK: - Backend API Configuration
    #if DEBUG
    static let backendURL = "http://localhost:3000"
    #else
    static let backendURL = "https://your-production-api.com"
    #endif
    
    // MARK: - Connect URLs
    static let connectReturnURL = "vibesy://stripe/onboard_complete"
    static let connectRefreshURL = "\(backendURL)/connect/refresh"
    
    // MARK: - API Endpoints
    struct Endpoints {
        static let connectOnboardLink = "/connect/onboard-link"
        static let connectStatus = "/connect/status"
        static let connectDisconnect = "/connect/disconnect"
        static let paymentIntent = "/payments/intent"
        static let paymentConfig = "/payments/config"
        static let ticketVerify = "/tickets/verify"
        static let ticketQR = "/tickets/qr"
        static let orderTickets = "/tickets/order"
    }
}

// MARK: - API Response Models
struct PaymentIntentResponse: Codable {
    let success: Bool
    let publishableKey: String
    let paymentIntentClientSecret: String
    let ephemeralKey: String
    let customer: String
    let orderId: Int
    let event: EventInfo
    let orderSummary: OrderSummary
    
    enum CodingKeys: String, CodingKey {
        case success, publishableKey, paymentIntentClientSecret, ephemeralKey, customer
        case orderId = "order_id"
        case event
        case orderSummary = "order_summary"
    }
}

struct EventInfo: Codable {
    let id: Int
    let title: String
    let venue: String
    let startsAt: String
    let priceCents: Int
    
    enum CodingKeys: String, CodingKey {
        case id, title, venue
        case startsAt = "starts_at"
        case priceCents = "price_cents"
    }
}

struct OrderSummary: Codable {
    let quantity: Int
    let ticketPriceCents: Int
    let totalAmountCents: Int
    let platformFeeCents: Int
    let currency: String
    
    enum CodingKeys: String, CodingKey {
        case quantity, currency
        case ticketPriceCents = "ticket_price_cents"
        case totalAmountCents = "total_amount_cents"
        case platformFeeCents = "platform_fee_cents"
    }
}

struct ConnectOnboardingResponse: Codable {
    let success: Bool
    let url: String?
    let accountId: String
    let onboardingComplete: Bool
    let message: String?
    
    enum CodingKeys: String, CodingKey {
        case success, url, message
        case accountId = "account_id"
        case onboardingComplete = "onboarding_complete"
    }
}

struct ConnectStatusResponse: Codable {
    let success: Bool
    let hasConnectAccount: Bool
    let accountId: String?
    let onboardingComplete: Bool
    let role: String?
    
    enum CodingKeys: String, CodingKey {
        case success, role
        case hasConnectAccount = "has_connect_account"
        case accountId = "account_id"
        case onboardingComplete = "onboarding_complete"
    }
}

struct TicketInfo: Codable, Identifiable {
    let id: Int
    let ticketNumber: String
    let qrToken: String
    let holderName: String?
    let holderEmail: String?
    let status: String
    let scannedAt: String?
    let createdAt: String
    let event: EventInfo
    
    enum CodingKeys: String, CodingKey {
        case id, status, event
        case ticketNumber = "ticket_number"
        case qrToken = "qr_token"
        case holderName = "holder_name"
        case holderEmail = "holder_email"
        case scannedAt = "scanned_at"
        case createdAt = "created_at"
    }
}

struct OrderTicketsResponse: Codable {
    let success: Bool
    let order: OrderInfo
    let tickets: [TicketInfo]
}

struct OrderInfo: Codable {
    let id: String
    let status: String
    let buyerName: String?
    let buyerEmail: String
    let amountCents: Int
    let ticketCount: Int
    
    enum CodingKeys: String, CodingKey {
        case id, status
        case buyerName = "buyer_name"
        case buyerEmail = "buyer_email"
        case amountCents = "amount_cents"
        case ticketCount = "ticket_count"
    }
}
