//
//  UserOrdersService.swift
//  Vibesy
//
//  Created by Alexander Cleoni on Ticket Integration.
//

import Foundation
import Combine
import os.log

@MainActor
class UserOrdersService: ObservableObject {
    static let shared = UserOrdersService()
    
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "Vibesy", category: "UserOrdersService")
    private let userDefaults = UserDefaults.standard
    private let userOrdersKey = "user_orders"
    
    @Published private(set) var userOrders: [UserOrder] = []
    
    private init() {
        loadUserOrders()
        cleanupInvalidOrders() // Clean up any invalid order IDs from previous versions
    }
    
    // MARK: - Public Methods
    
    /// Store an order after successful payment
    func storeOrder(eventId: String, userId: String, orderId: Int, ticketCount: Int) {
        let userOrder = UserOrder(
            eventId: eventId,
            userId: userId,
            orderId: orderId,
            ticketCount: ticketCount,
            purchasedAt: Date()
        )
        
        userOrders.append(userOrder)
        saveUserOrders()
        
        logger.info("Stored order \(orderId) for event \(eventId) and user \(userId)")
    }
    
    /// Get order ID for a specific event and user
    func getOrderId(for eventId: String, userId: String) -> Int? {
        return userOrders.first { $0.eventId == eventId && $0.userId == userId }?.orderId
    }
    
    /// Check if user has purchased tickets for an event
    func hasPurchasedTickets(for eventId: String, userId: String) -> Bool {
        return userOrders.contains { $0.eventId == eventId && $0.userId == userId }
    }
    
    /// Get all orders for a specific user
    func getOrders(for userId: String) -> [UserOrder] {
        return userOrders.filter { $0.userId == userId }
    }
    
    /// Get ticket count for a specific event and user
    func getTicketCount(for eventId: String, userId: String) -> Int {
        return userOrders.first { $0.eventId == eventId && $0.userId == userId }?.ticketCount ?? 0
    }
    
    /// Remove an order (e.g., if refunded)
    func removeOrder(eventId: String, userId: String) {
        userOrders.removeAll { $0.eventId == eventId && $0.userId == userId }
        saveUserOrders()
        
        logger.info("Removed order for event \(eventId) and user \(userId)")
    }
    
    /// Clear all order data (useful for debugging/reset)
    func clearAllOrders() {
        userOrders.removeAll()
        saveUserOrders()
        
        logger.info("Cleared all user orders")
    }
    
    /// Debug: Get all stored orders (for debugging)
    func getAllStoredOrders() -> [UserOrder] {
        logger.info("Debug - Total orders stored: \(self.userOrders.count)")
        for order in userOrders {
            logger.info("Debug - Order: eventId=\(order.eventId), userId=\(order.userId), orderId=\(order.orderId), ticketCount=\(order.ticketCount), purchasedAt=\(order.purchasedAt)")
        }
        return userOrders
    }
    
    /// Remove invalid order IDs (those that are too large for backend)
    func cleanupInvalidOrders() {
        let maxValidOrderId = 2147483647 // PostgreSQL integer max
        let originalCount = userOrders.count
        
        userOrders.removeAll { $0.orderId > maxValidOrderId }
        
        if userOrders.count != originalCount {
            saveUserOrders()
            logger.info("Cleaned up \(originalCount - self.userOrders.count) invalid orders")
        }
    }
    
    // MARK: - Private Methods
    
    private func loadUserOrders() {
        guard let data = userDefaults.data(forKey: userOrdersKey) else {
            logger.info("No saved user orders found")
            return
        }
        
        do {
            self.userOrders = try JSONDecoder().decode([UserOrder].self, from: data)
            logger.info("Loaded \(self.userOrders.count) user orders")
        } catch {
            logger.error("Failed to load user orders: \(error.localizedDescription)")
            self.userOrders = []
        }
    }
    
    private func saveUserOrders() {
        do {
            let data = try JSONEncoder().encode(self.userOrders)
            userDefaults.set(data, forKey: userOrdersKey)
            logger.info("Saved \(self.userOrders.count) user orders")
        } catch {
            logger.error("Failed to save user orders: \(error.localizedDescription)")
        }
    }
}

// MARK: - UserOrder Model

struct UserOrder: Codable, Identifiable {
    let id = UUID()
    let eventId: String
    let userId: String
    let orderId: Int
    let ticketCount: Int
    let purchasedAt: Date
    
    enum CodingKeys: String, CodingKey {
        case eventId = "event_id"
        case userId = "user_id"
        case orderId = "order_id"
        case ticketCount = "ticket_count"
        case purchasedAt = "purchased_at"
    }
}
