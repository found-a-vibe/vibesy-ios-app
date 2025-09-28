//
//  URLValidationService.swift
//  Vibesy
//
//  Created by Refactoring Bot on 12/19/24.
//

import Foundation
import Network
import os.log

// MARK: - URL Validation Service

final class URLValidationService: @unchecked Sendable {
    
    // MARK: - Properties
    
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "Vibesy", category: "URLValidation")
    
    // Network monitoring
    private let monitor = NWPathMonitor()
    private let monitorQueue = DispatchQueue(label: "URLValidationNetworkMonitor")
    
    // Performance caching
    private let validationCache = NSCache<NSString, URLValidationCacheEntry>()
    private let processingQueue = DispatchQueue(label: "URLValidationProcessing", qos: .userInitiated)
    
    // Blacklists and patterns
    private var maliciousDomains = Set<String>()
    private var scamPatterns: [NSRegularExpression] = []
    private var suspiciousKeywords = Set<String>()
    
    // Configuration
    private let requestTimeout: TimeInterval = 10.0
    private let cacheExpiryTime: TimeInterval = 3600 // 1 hour
    
    // MARK: - Initialization
    
    init() {
        setupDomainBlacklists()
        setupScamPatterns()
        setupNetworkMonitoring()
        configureCache()
        
        logger.info("URL Validation Service initialized")
    }
    
    // MARK: - Public API
    
    /// Validates a URL for malicious content and scam patterns
    func validateURL(_ url: URL) async throws -> URLValidationResult {
        // Check cache first
        let cacheKey = url.absoluteString as NSString
        if let cached = getCachedResult(cacheKey) {
            logger.debug("Using cached URL validation result for: \(url.host ?? "unknown")")
            return cached.result
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            processingQueue.async { [weak self] in
                guard let self = self else {
                    continuation.resume(throwing: URLValidationError.serviceUnavailable)
                    return
                }
                
                Task {
                    do {
                        let result = try await self.performURLValidation(url)
                        self.cacheResult(result, forKey: cacheKey)
                        continuation.resume(returning: result)
                    } catch {
                        continuation.resume(throwing: error)
                    }
                }
            }
        }
    }
    
    /// Batch validation for multiple URLs
    func validateURLs(_ urls: [URL]) async throws -> [URLValidationResult] {
        return try await withThrowingTaskGroup(of: (Int, URLValidationResult).self) { group in
            for (index, url) in urls.enumerated() {
                group.addTask { [weak self] in
                    guard let self = self else { throw URLValidationError.serviceUnavailable }
                    let result = try await self.validateURL(url)
                    return (index, result)
                }
            }
            
            var results: [(Int, URLValidationResult)] = []
            for try await result in group {
                results.append(result)
            }
            
            return results.sorted(by: { $0.0 < $1.0 }).map { $0.1 }
        }
    }
    
    /// Quick check for obviously malicious domains
    func isKnownMaliciousDomain(_ url: URL) -> Bool {
        guard let host = url.host?.lowercased() else { return false }
        
        // Check against known malicious domains
        if maliciousDomains.contains(host) {
            return true
        }
        
        // Check for suspicious TLDs
        let suspiciousTLDs = [".tk", ".ml", ".ga", ".cf", ".bit"]
        for tld in suspiciousTLDs {
            if host.hasSuffix(tld) {
                return true
            }
        }
        
        return false
    }
    
    // MARK: - Private Implementation
    
    private func performURLValidation(_ url: URL) async throws -> URLValidationResult {
        let startTime = CFAbsoluteTimeGetCurrent()
        
        var result = URLValidationResult(
            url: url,
            isMalicious: false,
            isScam: false,
            confidence: 0.0,
            riskFactors: [],
            processingTime: 0.0
        )
        
        // 1. Basic URL structure validation
        try validateURLStructure(url, result: &result)
        
        // 2. Domain reputation check
        await checkDomainReputation(url, result: &result)
        
        // 3. Scam pattern detection
        detectScamPatterns(url, result: &result)
        
        // 4. Content analysis (if accessible)
        await performContentAnalysis(url, result: &result)
        
        // 5. Calculate final risk score
        calculateRiskScore(&result)
        
        result.processingTime = CFAbsoluteTimeGetCurrent() - startTime
        
        logger.debug("URL validation completed for \(url.host ?? "unknown") in \(result.processingTime)s")
        
        return result
    }
    
    private func validateURLStructure(_ url: URL, result: inout URLValidationResult) throws {
        guard let host = url.host, !host.isEmpty else {
            result.riskFactors.append(.invalidStructure)
            throw URLValidationError.invalidURL
        }
        
        // Check for suspicious URL patterns
        let urlString = url.absoluteString.lowercased()
        
        // Extremely long URLs
        if urlString.count > 2000 {
            result.riskFactors.append(.suspiciousStructure)
        }
        
        // Too many subdomains
        let components = host.components(separatedBy: ".")
        if components.count > 5 {
            result.riskFactors.append(.suspiciousStructure)
        }
        
        // Suspicious characters in domain
        let suspiciousChars = CharacterSet(charactersIn: "0123456789-")
        let domainCharCount = host.unicodeScalars.filter { suspiciousChars.contains($0) }.count
        if Double(domainCharCount) / Double(host.count) > 0.5 {
            result.riskFactors.append(.suspiciousStructure)
        }
        
        // Check for URL shorteners
        let shorteners = ["bit.ly", "tinyurl.com", "t.co", "goo.gl", "ow.ly", "is.gd"]
        if shorteners.contains(where: { host.contains($0) }) {
            result.riskFactors.append(.urlShortener)
        }
        
        // IP address instead of domain
        if isIPAddress(host) {
            result.riskFactors.append(.ipAddress)
        }
    }
    
    private func checkDomainReputation(_ url: URL, result: inout URLValidationResult) async {
        guard let host = url.host?.lowercased() else { return }
        
        // Check against known malicious domains
        if maliciousDomains.contains(host) {
            result.isMalicious = true
            result.riskFactors.append(.knownMaliciousDomain)
            return
        }
        
        // Check domain age and reputation (simplified)
        if await isDomainSuspicious(host) {
            result.riskFactors.append(.suspiciousDomain)
        }
        
        // Check for typosquatting
        if isLikelyTyposquatting(host) {
            result.riskFactors.append(.typosquatting)
            result.isScam = true
        }
    }
    
    private func detectScamPatterns(_ url: URL, result: inout URLValidationResult) {
        let urlString = url.absoluteString.lowercased()
        
        // Check against scam patterns
        for pattern in scamPatterns {
            if pattern.numberOfMatches(in: urlString, range: NSRange(urlString.startIndex..., in: urlString)) > 0 {
                result.isScam = true
                result.riskFactors.append(.scamPattern)
                break
            }
        }
        
        // Check for suspicious keywords
        for keyword in suspiciousKeywords {
            if urlString.contains(keyword) {
                result.riskFactors.append(.suspiciousKeyword)
            }
        }
        
        // Check for phishing indicators
        if containsPhishingIndicators(urlString) {
            result.isScam = true
            result.riskFactors.append(.phishingIndicators)
        }
    }
    
    private func performContentAnalysis(_ url: URL, result: inout URLValidationResult) async {
        // Attempt to fetch and analyze page content (with timeout)
        do {
            let content = try await fetchPageContent(url)
            analyzePageContent(content, result: &result)
        } catch {
            logger.debug("Could not fetch content for URL analysis: \(error.localizedDescription)")
            result.riskFactors.append(.contentNotAccessible)
        }
    }
    
    private func calculateRiskScore(_ result: inout URLValidationResult) {
        var riskScore: Double = 0.0
        
        for factor in result.riskFactors {
            riskScore += factor.riskWeight
        }
        
        // Additional scoring based on flags
        if result.isMalicious {
            riskScore += 0.5
        }
        
        if result.isScam {
            riskScore += 0.4
        }
        
        result.confidence = min(riskScore, 1.0)
    }
    
    // MARK: - Helper Methods
    
    private func isIPAddress(_ host: String) -> Bool {
        let ipv4Regex = try! NSRegularExpression(pattern: #"^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$"#)
        return ipv4Regex.numberOfMatches(in: host, range: NSRange(host.startIndex..., in: host)) > 0
    }
    
    private func isDomainSuspicious(_ domain: String) async -> Bool {
        // Check if domain is very new (placeholder - would need external service)
        // In real implementation, you'd check domain registration date
        
        // Check for suspicious patterns in domain name
        let suspiciousPatterns = ["secure", "verify", "update", "confirm", "login"]
        for pattern in suspiciousPatterns {
            if domain.contains(pattern) {
                return true
            }
        }
        
        return false
    }
    
    private func isLikelyTyposquatting(_ domain: String) -> Bool {
        let popularDomains = ["google.com", "facebook.com", "amazon.com", "apple.com", "microsoft.com"]
        
        for popularDomain in popularDomains {
            if levenshteinDistance(domain, popularDomain) <= 2 && domain != popularDomain {
                return true
            }
        }
        
        return false
    }
    
    private func containsPhishingIndicators(_ urlString: String) -> Bool {
        let phishingPatterns = [
            "secure.*login", "verify.*account", "update.*payment",
            "confirm.*identity", "suspended.*account", "urgent.*action"
        ]
        
        for pattern in phishingPatterns {
            do {
                let regex = try NSRegularExpression(pattern: pattern, options: .caseInsensitive)
                if regex.numberOfMatches(in: urlString, range: NSRange(urlString.startIndex..., in: urlString)) > 0 {
                    return true
                }
            } catch {
                continue
            }
        }
        
        return false
    }
    
    private func fetchPageContent(_ url: URL) async throws -> String {
        var request = URLRequest(url: url)
        request.timeoutInterval = requestTimeout
        request.setValue("Mozilla/5.0 (compatible; VibesyBot/1.0)", forHTTPHeaderField: "User-Agent")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              200...299 ~= httpResponse.statusCode else {
            throw URLValidationError.networkError
        }
        
        return String(data: data, encoding: .utf8) ?? ""
    }
    
    private func analyzePageContent(_ content: String, result: inout URLValidationResult) {
        let lowercasedContent = content.lowercased()
        
        // Check for common scam/phishing content
        let scamIndicators = [
            "congratulations, you've won", "urgent action required",
            "verify your account", "suspended account", "click here immediately",
            "limited time offer", "act now", "100% guaranteed"
        ]
        
        for indicator in scamIndicators {
            if lowercasedContent.contains(indicator) {
                result.riskFactors.append(.maliciousContent)
                result.isScam = true
                break
            }
        }
        
        // Check for suspicious form fields
        if lowercasedContent.contains("password") && lowercasedContent.contains("social security") {
            result.riskFactors.append(.suspiciousForm)
            result.isScam = true
        }
        
        // Check for excessive redirects or JavaScript obfuscation
        if lowercasedContent.contains("window.location") || lowercasedContent.contains("document.location") {
            result.riskFactors.append(.suspiciousRedirect)
        }
    }
    
    private func levenshteinDistance(_ s1: String, _ s2: String) -> Int {
        let s1Array = Array(s1)
        let s2Array = Array(s2)
        let s1Count = s1Array.count
        let s2Count = s2Array.count
        
        var matrix = Array(repeating: Array(repeating: 0, count: s2Count + 1), count: s1Count + 1)
        
        for i in 0...s1Count {
            matrix[i][0] = i
        }
        
        for j in 0...s2Count {
            matrix[0][j] = j
        }
        
        for i in 1...s1Count {
            for j in 1...s2Count {
                let cost = s1Array[i-1] == s2Array[j-1] ? 0 : 1
                matrix[i][j] = min(
                    matrix[i-1][j] + 1,      // deletion
                    matrix[i][j-1] + 1,      // insertion
                    matrix[i-1][j-1] + cost  // substitution
                )
            }
        }
        
        return matrix[s1Count][s2Count]
    }
    
    // MARK: - Setup Methods
    
    private func setupDomainBlacklists() {
        // Load malicious domains from various sources
        maliciousDomains = Set([
            // Example malicious domains (in real implementation, load from updated lists)
            "malware-domain.com",
            "phishing-site.net",
            "scam-website.org"
        ])
        
        logger.info("Loaded \(self.maliciousDomains.count) malicious domains")
    }
    
    private func setupScamPatterns() {
        let patterns = [
            #"free.*money"#,
            #"win.*lottery"#,
            #"congratulations.*winner"#,
            #"claim.*prize"#,
            #"urgent.*verify"#,
            #"suspended.*account"#,
            #"click.*here.*now"#
        ]
        
        scamPatterns = patterns.compactMap { pattern in
            try? NSRegularExpression(pattern: pattern, options: .caseInsensitive)
        }
        
        suspiciousKeywords = Set([
            "phishing", "malware", "virus", "trojan", "scam",
            "fraud", "hack", "exploit", "suspicious"
        ])
        
        logger.info("Loaded \(self.scamPatterns.count) scam patterns")
    }
    
    private func setupNetworkMonitoring() {
        monitor.pathUpdateHandler = { path in
            // Network monitoring - log directly to avoid sendable capture issues
            if path.status != .satisfied {
                let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "Vibesy", category: "URLValidation")
                logger.warning("Network path not satisfied - URL validation may be limited")
            }
        }
        monitor.start(queue: monitorQueue)
    }
    
    // MARK: - Caching
    
    private func configureCache() {
        validationCache.countLimit = 1000
        validationCache.totalCostLimit = 10 * 1024 * 1024 // 10MB
    }
    
    private func getCachedResult(_ key: NSString) -> URLValidationCacheEntry? {
        guard let entry = validationCache.object(forKey: key),
              !entry.isExpired else {
            validationCache.removeObject(forKey: key)
            return nil
        }
        return entry
    }
    
    private func cacheResult(_ result: URLValidationResult, forKey key: NSString) {
        let entry = URLValidationCacheEntry(result: result, timestamp: Date())
        validationCache.setObject(entry, forKey: key)
    }
    
    deinit {
        monitor.cancel()
    }
}

// MARK: - Supporting Types

struct URLValidationResult {
    let url: URL
    var isMalicious: Bool
    var isScam: Bool
    var confidence: Double
    var riskFactors: [RiskFactor]
    var processingTime: TimeInterval
}

enum RiskFactor {
    case invalidStructure
    case suspiciousStructure
    case knownMaliciousDomain
    case suspiciousDomain
    case typosquatting
    case scamPattern
    case suspiciousKeyword
    case phishingIndicators
    case urlShortener
    case ipAddress
    case contentNotAccessible
    case maliciousContent
    case suspiciousForm
    case suspiciousRedirect
    
    var riskWeight: Double {
        switch self {
        case .invalidStructure: return 0.3
        case .suspiciousStructure: return 0.2
        case .knownMaliciousDomain: return 0.9
        case .suspiciousDomain: return 0.3
        case .typosquatting: return 0.7
        case .scamPattern: return 0.6
        case .suspiciousKeyword: return 0.2
        case .phishingIndicators: return 0.8
        case .urlShortener: return 0.1
        case .ipAddress: return 0.3
        case .contentNotAccessible: return 0.1
        case .maliciousContent: return 0.8
        case .suspiciousForm: return 0.6
        case .suspiciousRedirect: return 0.4
        }
    }
}

private class URLValidationCacheEntry {
    let result: URLValidationResult
    let timestamp: Date
    
    init(result: URLValidationResult, timestamp: Date) {
        self.result = result
        self.timestamp = timestamp
    }
    
    var isExpired: Bool {
        return Date().timeIntervalSince(timestamp) > 3600 // 1 hour
    }
}

enum URLValidationError: LocalizedError {
    case serviceUnavailable
    case invalidURL
    case networkError
    case timeout
    
    var errorDescription: String? {
        switch self {
        case .serviceUnavailable:
            return "URL validation service is unavailable"
        case .invalidURL:
            return "The provided URL is invalid"
        case .networkError:
            return "Network error occurred during URL validation"
        case .timeout:
            return "URL validation timed out"
        }
    }
}

// MARK: - Concurrency Safety

/// URLValidationService is used from concurrent contexts (task groups).
/// The type is a class with internal synchronization via dedicated queues
/// (e.g., `processingQueue`, `monitorQueue`) and uses thread-safe types
/// (NSCache is thread-safe for its basic operations). We therefore declare
/// it as `@unchecked Sendable` to satisfy Swift's Sendable checking for
/// @Sendable closures capturing `self`.
extension URLValidationService: @unchecked Sendable {}

