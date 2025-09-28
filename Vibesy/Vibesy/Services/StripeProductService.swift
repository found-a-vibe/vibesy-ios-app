//
//  StripeProductService.swift
//  Vibesy
//
//  Created by Alexander Cleoni on Stripe Products Integration.
//

import Foundation
import Combine
import os.log

@MainActor
class StripeProductService: ObservableObject {
    static let shared = StripeProductService()
    
    private let networkService = EnhancedNetworkService.shared
    private let baseURL = StripeConfig.backendURL
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "Vibesy", category: "StripeProductService")
    
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
    
    // MARK: - Product Management
    
    /// Create a Stripe product for an event
    func createProduct(for event: Event, connectedAccountId: String) async throws -> StripeProductResponse {
        guard let url = URL(string: "\(baseURL)/stripe/products") else {
            throw APIError.invalidResponse
        }
        
        let body = [
            "eventId": event.id.uuidString,
            "name": event.title,
            "description": event.description,
            "metadata": [
                "event_id": event.id.uuidString,
                "event_title": event.title,
                "event_date": event.date,
                "event_location": event.location,
                "created_by": event.createdBy,
                "platform": "vibesy"
            ],
            "connected_account_id": connectedAccountId
        ] as [String: Any]
        
        do {
            let bodyData = try JSONSerialization.data(withJSONObject: body)
            
            logger.info("Creating Stripe product for event: \(event.id.uuidString)")
            
            return try await networkService.post(
                url: url,
                body: bodyData,
                headers: [:],
                responseType: StripeProductResponse.self,
                retryConfig: .default
            )
        } catch {
            logger.error("Failed to create Stripe product: \(error.localizedDescription)")
            try handleAPIError(error)
            throw error
        }
    }
    
    /// Update a Stripe product
    func updateProduct(_ productId: String, for event: Event, connectedAccountId: String) async throws -> StripeProductResponse {
        guard let url = URL(string: "\(baseURL)/stripe/products/\(productId)") else {
            throw APIError.invalidResponse
        }
        
        let body = [
            "name": event.title,
            "description": event.description,
            "metadata": [
                "event_id": event.id.uuidString,
                "event_title": event.title,
                "event_date": event.date,
                "event_location": event.location,
                "created_by": event.createdBy,
                "platform": "vibesy"
            ],
            "connected_account_id": connectedAccountId
        ] as [String: Any]
        
        do {
            let bodyData = try JSONSerialization.data(withJSONObject: body)
            
            logger.info("Updating Stripe product: \(productId)")
            
            return try await networkService.put(
                url: url,
                body: bodyData,
                headers: [:],
                responseType: StripeProductResponse.self,
                retryConfig: .default
            )
        } catch {
            logger.error("Failed to update Stripe product: \(error.localizedDescription)")
            try handleAPIError(error)
            throw error
        }
    }
    
    // MARK: - Price Management
    
    /// Create a Stripe price for a product
    func createPrice(for priceDetails: PriceDetails, productId: String, eventId: UUID, connectedAccountId: String) async throws -> StripePriceResponse {
        guard let url = URL(string: "\(baseURL)/stripe/prices") else {
            throw APIError.invalidResponse
        }
        
        // Convert Decimal to cents for Stripe
        let amountCents = NSDecimalNumber(decimal: priceDetails.price * Decimal(100)).intValue
        
        let body = [
            "product_id": productId,
            "unit_amount": amountCents,
            "currency": priceDetails.currency.rawValue.lowercased(),
            "nickname": priceDetails.title,
            "metadata": [
                "event_id": eventId.uuidString,
                "price_details_id": priceDetails.id.uuidString,
                "price_title": priceDetails.title,
                "price_type": priceDetails.type.rawValue,
                "currency": priceDetails.currency.rawValue,
                "platform": "vibesy"
            ],
            "connected_account_id": connectedAccountId
        ] as [String: Any]
        
        do {
            let bodyData = try JSONSerialization.data(withJSONObject: body)
            
            logger.info("Creating Stripe price for product: \(productId)")
            
            return try await networkService.post(
                url: url,
                body: bodyData,
                headers: [:],
                responseType: StripePriceResponse.self,
                retryConfig: .default
            )
        } catch {
            logger.error("Failed to create Stripe price: \(error.localizedDescription)")
            try handleAPIError(error)
            throw error
        }
    }
    
    /// Update a Stripe price
    func updatePrice(_ priceId: String, nickname: String?, metadata: [String: String]? = nil, connectedAccountId: String) async throws -> StripePriceResponse {
        guard let url = URL(string: "\(baseURL)/stripe/prices/\(priceId)") else {
            throw APIError.invalidResponse
        }
        
        var body: [String: Any] = [
            "connected_account_id": connectedAccountId
        ]
        
        if let nickname = nickname {
            body["nickname"] = nickname
        }
        
        if let metadata = metadata {
            body["metadata"] = metadata
        }
        
        do {
            let bodyData = try JSONSerialization.data(withJSONObject: body)
            
            logger.info("Updating Stripe price: \(priceId)")
            
            return try await networkService.put(
                url: url,
                body: bodyData,
                headers: [:],
                responseType: StripePriceResponse.self,
                retryConfig: .default
            )
        } catch {
            logger.error("Failed to update Stripe price: \(error.localizedDescription)")
            try handleAPIError(error)
            throw error
        }
    }
    
    /// Get prices for a product
    func getPrices(for productId: String, connectedAccountId: String) async throws -> StripePricesListResponse {
        guard let url = URL(string: "\(baseURL)/stripe/products/\(productId)/prices?connected_account_id=\(connectedAccountId)") else {
            throw APIError.invalidResponse
        }
        
        do {
            logger.info("Getting prices for product: \(productId)")
            
            return try await networkService.get(
                url: url,
                headers: [:],
                responseType: StripePricesListResponse.self,
                retryConfig: .default
            )
        } catch {
            logger.error("Failed to get prices for product: \(error.localizedDescription)")
            try handleAPIError(error)
            throw error
        }
    }
    
    // MARK: - Convenience Methods
    
    /// Create a complete Stripe product with prices for an event
    func createEventProductWithPrices(event: Event, connectedAccountId: String) async throws -> EventStripeInfo {
        // Create the product
        let productResponse = try await createProduct(for: event, connectedAccountId: connectedAccountId)
        
        // Create prices for each PriceDetails
        var priceResponses: [StripePriceResponse] = []
        
        for priceDetail in event.priceDetails {
            let priceResponse = try await createPrice(
                for: priceDetail,
                productId: productResponse.id,
                eventId: event.id,
                connectedAccountId: connectedAccountId
            )
            priceResponses.append(priceResponse)
        }
        
        return EventStripeInfo(
            productId: productResponse.id,
            connectedAccountId: connectedAccountId,
            priceIds: priceResponses.map { $0.id }
        )
    }
}

// MARK: - Response Models

struct StripeProductResponse: Codable {
    let id: String
    let name: String
    let description: String?
    let metadata: [String: String]
    let created: Int
    let updated: Int
    
    enum CodingKeys: String, CodingKey {
        case id, name, description, metadata, created, updated
    }
}

struct StripePriceResponse: Codable {
    let id: String
    let productId: String
    let unitAmount: Int
    let currency: String
    let nickname: String?
    let metadata: [String: String]
    let created: Int
    
    enum CodingKeys: String, CodingKey {
        case id
        case productId = "product"
        case unitAmount = "unit_amount"
        case currency, nickname, metadata, created
    }
}

struct StripePricesListResponse: Codable {
    let data: [StripePriceResponse]
    let hasMore: Bool
    
    enum CodingKeys: String, CodingKey {
        case data
        case hasMore = "has_more"
    }
}

struct EventStripeInfo: Codable {
    let productId: String
    let connectedAccountId: String
    let priceIds: [String]
}

