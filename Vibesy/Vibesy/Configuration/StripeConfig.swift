//
//  StripeConfig.swift
//  Vibesy
//
//  Created by Alexander Cleoni on Payment Integration.
//

import Foundation

struct StripeConfig {
    // MARK: - Environment Configuration
    private static let configPlistName: String = {
        #if DEBUG
        return "StripeKeys-Development"
        #else
        return "StripeKeys-Production"
        #endif
    }()
    
    private static func loadConfig() -> [String: Any]? {
        guard let path = Bundle.main.path(forResource: configPlistName, ofType: "plist"),
              let config = NSDictionary(contentsOfFile: path) as? [String: Any] else {
            print("⚠️ Warning: Could not load \(configPlistName).plist")
            return nil
        }
        return config
    }
    
    // MARK: - Stripe Configuration
    static let publishableKey: String = {
        guard let config = loadConfig(),
              let key = config["StripePublishableKey"] as? String else {
            print("⚠️ Warning: Using fallback test key - configure \(configPlistName).plist")
            return "pk_test_51S99XIBpogKxZeV1ai7zkBp6jABrlHsbvbt2oHaWd90mETLkwqmPRoheP4So1FD2aUJQmhh3IlwCSG5VBTEuMlFk00pHTe8881"
        }
        return key
    }()
    
    static let merchantId: String = {
        guard let config = loadConfig(),
              let id = config["MerchantId"] as? String else {
            return "merchant.com.vibesy"
        }
        return id
    }()
    
    static let merchantCountryCode = "US"
    static let currency = "usd"
    
    // MARK: - PaymentSheet Configuration
    static let merchantDisplayName = "Vibesy"
    static let returnURL = "vibesy://payment_complete"
    
    // MARK: - Backend API Configuration
    static let backendURL: String = {
        guard let config = loadConfig(),
              let url = config["BackendURL"] as? String else {
            return "https://one-time-password-service.onrender.com"
        }
        return url
    }()

    // MARK: - Connect URLs
    // Note: Stripe requires valid HTTP/HTTPS URLs, not custom schemes
    // The web page will handle redirecting back to the app
    static let connectReturnURL = "\(backendURL)/connect/return"
    static let connectRefreshURL = "\(backendURL)/connect/refresh"
    
    // MARK: - API Endpoints
    struct Endpoints {
        static let connectOnboardLink = "/connect/onboard-link"
        static let connectStatus = "/connect/status"
        static let connectDisconnect = "/connect/disconnect"
        static let connectDashboard = "/connect/dashboard-link"
        static let paymentIntent = "/payments/intent"
        static let paymentConfig = "/payments/config"
        static let ticketVerify = "/tickets/verify"
        static let ticketQR = "/tickets/qr"
        static let orderTickets = "/tickets/order"
        static let invoiceDetails = "/payments/invoice"
        static let paymentReceipt = "/payments/receipt"
    }
}

// MARK: - API Response Models
// Note: PaymentIntentResponse for reservation system is in PaymentService.swift
// This TicketPaymentIntentResponse is for the legacy ticket system

struct TicketPaymentIntentResponse: Codable {
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
    let hasConnectAccount: Bool?
    let accountId: String?
    let onboardingComplete: Bool
    let role: String?
    
    enum CodingKeys: String, CodingKey {
        case success, role
        case hasConnectAccount = "has_connect_account"
        case accountId = "account_id"
        case onboardingComplete = "onboarding_complete"
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        success = try container.decode(Bool.self, forKey: .success)
        hasConnectAccount = try container.decodeIfPresent(Bool.self, forKey: .hasConnectAccount)
        accountId = try container.decodeIfPresent(String.self, forKey: .accountId)
        role = try container.decodeIfPresent(String.self, forKey: .role)
        
        // Handle onboardingComplete more gracefully
        if let onboardingValue = try? container.decodeIfPresent(Bool.self, forKey: .onboardingComplete) {
            onboardingComplete = onboardingValue
        } else {
            // Default to false if the field is missing or can't be decoded
            print("⚠️ Warning: onboarding_complete field missing or invalid, defaulting to false")
            onboardingComplete = false
        }
    }
}

struct ConnectDashboardResponse: Codable {
    let success: Bool
    let url: String?
    let message: String?
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

// MARK: - Invoice Models

struct InvoiceResponse: Codable {
    let success: Bool
    let invoice: StripeInvoiceDetail?
    let error: String?
}

struct StripeInvoiceDetail: Codable {
    let id: String
    let paymentIntentId: String?
    let status: String
    let amountDue: Int
    let amountPaid: Int
    let currency: String
    let customerEmail: String?
    let description: String?
    let invoiceDate: String
    let dueDate: String?
    let receiptNumber: String?
    let receiptURL: String?
    let invoiceURL: String?
    let lineItems: [InvoiceLineItem]
    
    enum CodingKeys: String, CodingKey {
        case id, status, currency, description
        case paymentIntentId = "payment_intent_id"
        case amountDue = "amount_due"
        case amountPaid = "amount_paid"
        case customerEmail = "customer_email"
        case invoiceDate = "invoice_date"
        case dueDate = "due_date"
        case receiptNumber = "receipt_number"
        case receiptURL = "receipt_url"
        case invoiceURL = "invoice_url"
        case lineItems = "line_items"
    }
}

struct InvoiceLineItem: Codable {
    let description: String?
    let quantity: Int
    let unitAmount: Int
    let amount: Int
    let currency: String
    
    enum CodingKeys: String, CodingKey {
        case description, quantity, amount, currency
        case unitAmount = "unit_amount"
    }
}

struct PaymentReceiptResponse: Codable {
    let success: Bool
    let receipt: PaymentReceiptDetail?
    let error: String?
}

struct PaymentReceiptDetail: Codable {
    let paymentIntentId: String
    let receiptNumber: String?
    let receiptURL: String?
    let amountPaid: Int
    let currency: String
    let paymentMethod: String?
    let paymentDate: String
    let customerEmail: String?
    let description: String?
    let status: String
    
    enum CodingKeys: String, CodingKey {
        case status, currency, description
        case paymentIntentId = "payment_intent_id"
        case receiptNumber = "receipt_number"
        case receiptURL = "receipt_url"
        case amountPaid = "amount_paid"
        case paymentMethod = "payment_method"
        case paymentDate = "payment_date"
        case customerEmail = "customer_email"
    }
}

// MARK: - QR Code Invoice Data

struct QRInvoiceData: Codable {
    let ticketToken: String
    let invoiceId: String?
    let paymentIntentId: String?
    let receiptURL: String?
    let amountPaid: Int
    let currency: String
    let paymentDate: String
    let customerEmail: String?
    let eventTitle: String
    let ticketType: String?
    let quantity: Int
    
    enum CodingKeys: String, CodingKey {
        case currency, quantity
        case ticketToken = "ticket_token"
        case invoiceId = "invoice_id"
        case paymentIntentId = "payment_intent_id"
        case receiptURL = "receipt_url"
        case amountPaid = "amount_paid"
        case paymentDate = "payment_date"
        case customerEmail = "customer_email"
        case eventTitle = "event_title"
        case ticketType = "ticket_type"
    }
}
