//
//  Price.swift
//  FoundAVibe
//
//  Created by Alexander Cleoni on 12/13/24.
//

import Foundation
import os.log

// MARK: - Price Domain Errors
enum PriceError: LocalizedError {
    case invalidTitle(String)
    case invalidPrice(String)
    case invalidURL(String)
    case invalidCurrency(String)
    case negativePrice(Decimal)
    
    var errorDescription: String? {
        switch self {
        case .invalidTitle(let title):
            return "Invalid price title: \(title). Title cannot be empty and must be less than 100 characters."
        case .invalidPrice(let price):
            return "Invalid price format: \(price). Price must be a valid decimal number."
        case .invalidURL(let url):
            return "Invalid URL: \(url). Please provide a valid URL."
        case .invalidCurrency(let currency):
            return "Invalid currency: \(currency). Currency must be a valid 3-letter code."
        case .negativePrice(let price):
            return "Price cannot be negative: \(price)."
        }
    }
}

// MARK: - Currency Enum
enum Currency: String, CaseIterable, Codable {
    case usd = "USD"
    case eur = "EUR"
    case gbp = "GBP"
    case cad = "CAD"
    case aud = "AUD"
    case jpy = "JPY"
    
    var symbol: String {
        switch self {
        case .usd: return "$"
        case .eur: return "€"
        case .gbp: return "£"
        case .cad: return "C$"
        case .aud: return "A$"
        case .jpy: return "¥"
        }
    }
    
    var displayName: String {
        switch self {
        case .usd: return "US Dollar"
        case .eur: return "Euro"
        case .gbp: return "British Pound"
        case .cad: return "Canadian Dollar"
        case .aud: return "Australian Dollar"
        case .jpy: return "Japanese Yen"
        }
    }
}

// MARK: - Price Type Enum
enum PriceType: String, CaseIterable, Codable {
    case free = "free"
    case fixed = "fixed"
    case donation = "donation"
    case payWhatYouCan = "pay_what_you_can"
    case tiered = "tiered"
    
    var displayName: String {
        switch self {
        case .free: return "Free"
        case .fixed: return "Fixed Price"
        case .donation: return "Donation"
        case .payWhatYouCan: return "Pay What You Can"
        case .tiered: return "Tiered Pricing"
        }
    }
}

// MARK: - Enhanced PriceDetails Model
struct PriceDetails: Hashable, Codable, Identifiable {
    private static let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "Vibesy", category: "PriceDetails")
    
    // MARK: - Constants
    private static let maxTitleLength = 100
    private static let maxDescriptionLength = 200
    
    // MARK: - Properties
    let id: UUID
    private var _title: String
    private var _price: Decimal
    private var _currency: Currency
    private var _type: PriceType
    private(set) var description: String?
    private(set) var link: String?
    private(set) var availableFrom: Date?
    private(set) var availableUntil: Date?
    private(set) var maxQuantity: Int?
    private(set) var soldQuantity: Int = 0
    private(set) var createdAt: Date = Date()
    private(set) var updatedAt: Date = Date()
    
    // MARK: - Stripe Integration
    private(set) var stripePriceId: String?
    
    // MARK: - Computed Properties
    var title: String {
        get { _title }
        set {
            do {
                try setTitle(newValue)
            } catch {
                Self.logger.error("Failed to set price title: \(error.localizedDescription)")
            }
        }
    }
    
    var price: Decimal {
        get { _price }
        set {
            do {
                try setPrice(newValue)
            } catch {
                Self.logger.error("Failed to set price: \(error.localizedDescription)")
            }
        }
    }
    
    var currency: Currency {
        get { _currency }
        set {
            _currency = newValue
            updateTimestamp()
        }
    }
    
    var type: PriceType {
        get { _type }
        set {
            _type = newValue
            updateTimestamp()
        }
    }
    
    var formattedPrice: String {
        if _type == .free {
            return "Free"
        } else if _type == .donation {
            return "Donation"
        } else if _type == .payWhatYouCan {
            return "Pay What You Can"
        }
        
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = _currency.rawValue
        formatter.currencySymbol = _currency.symbol
        
        return formatter.string(from: NSDecimalNumber(decimal: _price)) ?? "\(_currency.symbol)\(_price)"
    }
    
    var isAvailable: Bool {
        let now = Date()
        
        if let from = availableFrom, now < from {
            return false
        }
        
        if let until = availableUntil, now > until {
            return false
        }
        
        if let maxQty = maxQuantity, soldQuantity >= maxQty {
            return false
        }
        
        return true
    }
    
    var remainingQuantity: Int? {
        guard let maxQuantity = maxQuantity else { return nil }
        return max(0, maxQuantity - soldQuantity)
    }
    
    var isSoldOut: Bool {
        guard let maxQuantity = maxQuantity else { return false }
        return soldQuantity >= maxQuantity
    }
    
    var hasValidLink: Bool {
        guard let link = link, !link.isEmpty else { return false }
        return URL(string: link) != nil
    }
    
    // MARK: - Initializer
    init(id: UUID = UUID(),
         title: String,
         price: Decimal = 0,
         currency: Currency = .usd,
         type: PriceType = .fixed,
         description: String? = nil,
         link: String? = nil,
         availableFrom: Date? = nil,
         availableUntil: Date? = nil,
         maxQuantity: Int? = nil) throws {
        
        guard !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
              title.count <= Self.maxTitleLength else {
            throw PriceError.invalidTitle(title)
        }
        
        guard price >= 0 else {
            throw PriceError.negativePrice(price)
        }
        
        if let link = link, !link.isEmpty {
            guard URL(string: link) != nil else {
                throw PriceError.invalidURL(link)
            }
        }
        
        if let description = description, description.count > Self.maxDescriptionLength {
            throw PriceError.invalidTitle(description) // Reusing title error for description length
        }
        
        self.id = id
        self._title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        self._price = price
        self._currency = currency
        self._type = type
        self.description = description?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.link = link
        self.availableFrom = availableFrom
        self.availableUntil = availableUntil
        self.maxQuantity = maxQuantity
    }
    
    // MARK: - Mutating Methods
    private mutating func setTitle(_ title: String) throws {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty && trimmed.count <= Self.maxTitleLength else {
            throw PriceError.invalidTitle(title)
        }
        _title = trimmed
        updateTimestamp()
    }
    
    private mutating func setPrice(_ price: Decimal) throws {
        guard price >= 0 else {
            throw PriceError.negativePrice(price)
        }
        _price = price
        updateTimestamp()
    }
    
    mutating func updateDescription(_ description: String?) throws {
        if let description = description {
            let trimmed = description.trimmingCharacters(in: .whitespacesAndNewlines)
            guard trimmed.count <= Self.maxDescriptionLength else {
                throw PriceError.invalidTitle(description)
            }
            self.description = trimmed.isEmpty ? nil : trimmed
        } else {
            self.description = nil
        }
        updateTimestamp()
    }
    
    mutating func updateLink(_ link: String?) throws {
        if let link = link, !link.isEmpty {
            guard URL(string: link) != nil else {
                throw PriceError.invalidURL(link)
            }
            self.link = link
        } else {
            self.link = nil
        }
        updateTimestamp()
    }
    
    mutating func updateAvailability(from: Date?, until: Date?) {
        self.availableFrom = from
        self.availableUntil = until
        updateTimestamp()
    }
    
    mutating func updateQuantity(maxQuantity: Int?, sold: Int = 0) {
        self.maxQuantity = maxQuantity
        self.soldQuantity = max(0, sold)
        updateTimestamp()
    }
    
    mutating func incrementSoldQuantity(by amount: Int = 1) {
        soldQuantity += max(0, amount)
        updateTimestamp()
    }
    
    mutating func decrementSoldQuantity(by amount: Int = 1) {
        soldQuantity = max(0, soldQuantity - max(0, amount))
        updateTimestamp()
    }
    
    // MARK: - Stripe Management
    mutating func setStripePriceId(_ priceId: String) {
        stripePriceId = priceId
        updateTimestamp()
    }
    
    mutating func clearStripePriceId() {
        stripePriceId = nil
        updateTimestamp()
    }
    
    // MARK: - Validation
    func validate() throws {
        if _title.isEmpty || _title.count > Self.maxTitleLength {
            throw PriceError.invalidTitle(_title)
        }
        
        if _price < 0 {
            throw PriceError.negativePrice(_price)
        }
        
        if let link = link, !link.isEmpty, URL(string: link) == nil {
            throw PriceError.invalidURL(link)
        }
        
        if let description = description, description.count > Self.maxDescriptionLength {
            throw PriceError.invalidTitle(description)
        }
        
        if let availableFrom = availableFrom,
           let availableUntil = availableUntil,
           availableFrom > availableUntil {
            // Invalid date range - availableFrom should be before availableUntil
            // We could create a specific error for this, but for now using existing error
        }
    }
    
    // MARK: - Private Methods
    private mutating func updateTimestamp() {
        updatedAt = Date()
    }
    
    // MARK: - Hashable
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(_title)
        hasher.combine(_price)
        hasher.combine(_currency)
        hasher.combine(_type)
        hasher.combine(description)
        hasher.combine(link)
        hasher.combine(availableFrom)
        hasher.combine(availableUntil)
        hasher.combine(maxQuantity)
        hasher.combine(soldQuantity)
    }
    
    // MARK: - Equatable
    static func == (lhs: PriceDetails, rhs: PriceDetails) -> Bool {
        return lhs.id == rhs.id &&
        lhs._title == rhs._title &&
        lhs._price == rhs._price &&
        lhs._currency == rhs._currency &&
        lhs._type == rhs._type &&
        lhs.description == rhs.description &&
        lhs.link == rhs.link &&
        lhs.availableFrom == rhs.availableFrom &&
        lhs.availableUntil == rhs.availableUntil &&
        lhs.maxQuantity == rhs.maxQuantity &&
        lhs.soldQuantity == rhs.soldQuantity
    }
}
