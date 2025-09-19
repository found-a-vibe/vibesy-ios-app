//
//  EnhancedContentModerationService.swift
//  Vibesy
//
//  Created by Refactoring Bot on 12/19/24.
//

import Foundation
import UIKit
import CoreML
import Vision
import NaturalLanguage
import os.log
import CryptoKit

// MARK: - Content Moderation Types

enum ContentType {
    case text(String)
    case image(UIImage)
    case url(URL)
    case hashtags([String])
    case userProfile(UserProfile)
    case event(Event)
}

enum ModerationResult {
    case approved
    case flagged(reasons: [FlagReason], confidence: Double)
    case blocked(reasons: [FlagReason], confidence: Double)
    case requiresReview(reasons: [FlagReason], confidence: Double)
}

enum FlagReason {
    case profanity(severity: ProfanitySeverity)
    case explicitContent(type: ExplicitContentType)
    case harassment
    case spam
    case violence
    case hateSpeech
    case inappropriateImage(type: ImageViolationType)
    case personalInformation
    case scam
    case maliciousURL
    case repetitiveContent
    case copyright
    case custom(String)
}

enum ProfanitySeverity {
    case mild
    case moderate
    case severe
    case extreme
}

enum ExplicitContentType {
    case nsfw
    case suggestive
    case violence
    case drugs
    case alcohol
}

enum ImageViolationType {
    case nsfw(confidence: Double)
    case violence(confidence: Double)
    case inappropriate(confidence: Double)
    case lowQuality(confidence: Double)
}

// MARK: - Content Moderation Configuration

struct ContentModerationConfig {
    // Text moderation thresholds
    let profanityThreshold: Double = 0.7
    let harassmentThreshold: Double = 0.6
    let spamThreshold: Double = 0.8
    
    // Image moderation thresholds
    let nsfwThreshold: Double = 0.7
    let violenceThreshold: Double = 0.8
    let qualityThreshold: Double = 0.3
    
    // Performance settings
    let enableCaching: Bool = true
    let cacheExpiryTime: TimeInterval = 3600 // 1 hour
    let maxCacheSize: Int = 1000
    
    // Async processing
    let enableAsyncProcessing: Bool = true
    let maxConcurrentOperations: Int = 3
    
    // Localization
    let supportedLanguages: [String] = ["en", "es", "fr", "de", "it", "pt", "ja", "zh", "ru", "pl"]
    
    static let `default` = ContentModerationConfig()
}

// MARK: - Enhanced Content Moderation Service

@MainActor
final class EnhancedContentModerationService: ObservableObject {
    static let shared = EnhancedContentModerationService()
    
    private let config = ContentModerationConfig.default
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "Vibesy", category: "ContentModeration")
    
    // MARK: - Core Services
    private let profanityService = EnhancedProfanityService()
    private let imageService = EnhancedImageModerationService()
    private let textAnalysisService = TextAnalysisService()
    private let urlValidationService = URLValidationService()
    
    // MARK: - Caching
    private let cache = NSCache<NSString, CachedModerationResult>()
    private let cacheQueue = DispatchQueue(label: "ContentModerationCache", qos: .utility)
    
    // MARK: - Performance Management
    private let operationQueue: OperationQueue
    private let processingQueue = DispatchQueue(label: "ContentModerationProcessing", qos: .userInitiated, attributes: .concurrent)
    
    // MARK: - Statistics
    @Published var moderationStats = ModerationStatistics()
    
    private init() {
        // Configure operation queue
        operationQueue = OperationQueue()
        operationQueue.maxConcurrentOperationCount = config.maxConcurrentOperations
        operationQueue.qualityOfService = .userInitiated
        
        // Configure cache
        cache.countLimit = config.maxCacheSize
        
        logger.info("Enhanced Content Moderation Service initialized")
    }
    
    // MARK: - Public API
    
    /// Moderates content with comprehensive filtering
    func moderateContent(_ content: ContentType) async throws -> ModerationResult {
        let startTime = CFAbsoluteTimeGetCurrent()
        
        // Check cache first
        if config.enableCaching, let cachedResult = getCachedResult(for: content) {
            logger.debug("Using cached moderation result")
            moderationStats.recordCacheHit()
            return cachedResult.result
        }
        
        let result: ModerationResult
        
        switch content {
        case .text(let text):
            result = try await moderateText(text)
            
        case .image(let image):
            result = try await moderateImage(image)
            
        case .url(let url):
            result = try await moderateURL(url)
            
        case .hashtags(let hashtags):
            result = try await moderateHashtags(hashtags)
            
        case .userProfile(let profile):
            result = try await moderateUserProfile(profile)
            
        case .event(let event):
            result = try await moderateEvent(event)
        }
        
        // Cache the result
        if config.enableCaching {
            cacheResult(result, for: content)
        }
        
        // Record statistics
        let processingTime = CFAbsoluteTimeGetCurrent() - startTime
        moderationStats.recordModeration(result: result, processingTime: processingTime)
        
        logger.debug("Content moderation completed in \(processingTime)s")
        return result
    }
    
    /// Bulk moderation for multiple content items
    func moderateContentBatch(_ contents: [ContentType]) async throws -> [ModerationResult] {
        guard !contents.isEmpty else { return [] }
        
        logger.info("Starting batch moderation for \(contents.count) items")
        
        return try await withThrowingTaskGroup(of: (Int, ModerationResult).self) { group in
            // Add tasks for each content item
            for (index, content) in contents.enumerated() {
                group.addTask { [weak self] in
                    guard let self = self else { throw ContentModerationError.serviceUnavailable }
                    let result = try await self.moderateContent(content)
                    return (index, result)
                }
            }
            
            // Collect results in order
            var results: [(Int, ModerationResult)] = []
            for try await result in group {
                results.append(result)
            }
            
            // Sort by index and return results
            return results.sorted(by: { $0.0 < $1.0 }).map { $0.1 }
        }
    }
    
    // MARK: - Content-Specific Moderation
    
    private func moderateText(_ text: String) async throws -> ModerationResult {
        let sanitizedText = textAnalysisService.sanitizeText(text)
        var flagReasons: [FlagReason] = []
        var totalConfidence: Double = 0
        var checks: Int = 0
        
        // Profanity check
        if let profanityResult = try await profanityService.checkProfanity(sanitizedText) {
            flagReasons.append(profanityResult.reason)
            totalConfidence += profanityResult.confidence
            checks += 1
        }
        
        // Harassment detection
        if let harassmentScore = try await textAnalysisService.detectHarassment(sanitizedText),
           harassmentScore > config.harassmentThreshold {
            flagReasons.append(.harassment)
            totalConfidence += harassmentScore
            checks += 1
        }
        
        // Spam detection
        if let spamScore = try await textAnalysisService.detectSpam(sanitizedText),
           spamScore > config.spamThreshold {
            flagReasons.append(.spam)
            totalConfidence += spamScore
            checks += 1
        }
        
        // Personal information detection
        if textAnalysisService.containsPersonalInformation(sanitizedText) {
            flagReasons.append(.personalInformation)
            totalConfidence += 0.9
            checks += 1
        }
        
        // Calculate average confidence
        let averageConfidence = checks > 0 ? totalConfidence / Double(checks) : 0
        
        return determineResult(flagReasons: flagReasons, confidence: averageConfidence)
    }
    
    private func moderateImage(_ image: UIImage) async throws -> ModerationResult {
        var flagReasons: [FlagReason] = []
        var totalConfidence: Double = 0
        var checks: Int = 0
        
        // NSFW detection
        if let nsfwScore = try await imageService.detectNSFW(image) {
            if nsfwScore > config.nsfwThreshold {
                flagReasons.append(.inappropriateImage(type: .nsfw(confidence: nsfwScore)))
            }
            totalConfidence += nsfwScore
            checks += 1
        }
        
        // Violence detection
        if let violenceScore = try await imageService.detectViolence(image),
           violenceScore > config.violenceThreshold {
            flagReasons.append(.inappropriateImage(type: .violence(confidence: violenceScore)))
            totalConfidence += violenceScore
            checks += 1
        }
        
        // Image quality check
        let qualityScore = try await imageService.assessImageQuality(image)
        if qualityScore < config.qualityThreshold {
            flagReasons.append(.inappropriateImage(type: .lowQuality(confidence: 1.0 - qualityScore)))
            totalConfidence += (1.0 - qualityScore)
            checks += 1
        }
        
        // Calculate average confidence
        let averageConfidence = checks > 0 ? totalConfidence / Double(checks) : 0
        
        return determineResult(flagReasons: flagReasons, confidence: averageConfidence)
    }
    
    private func moderateURL(_ url: URL) async throws -> ModerationResult {
        let validationResult = try await urlValidationService.validateURL(url)
        
        var flagReasons: [FlagReason] = []
        
        if validationResult.isMalicious {
            flagReasons.append(.maliciousURL)
        }
        
        if validationResult.isScam {
            flagReasons.append(.scam)
        }
        
        return determineResult(flagReasons: flagReasons, confidence: validationResult.confidence)
    }
    
    private func moderateHashtags(_ hashtags: [String]) async throws -> ModerationResult {
        var flagReasons: [FlagReason] = []
        var totalConfidence: Double = 0
        var checks: Int = 0
        
        for hashtag in hashtags {
            if let profanityResult = try await profanityService.checkProfanity(hashtag) {
                flagReasons.append(profanityResult.reason)
                totalConfidence += profanityResult.confidence
                checks += 1
            }
        }
        
        // Check for hashtag spam patterns
        if textAnalysisService.detectHashtagSpam(hashtags) {
            flagReasons.append(.spam)
            totalConfidence += 0.8
            checks += 1
        }
        
        let averageConfidence = checks > 0 ? totalConfidence / Double(checks) : 0
        
        return determineResult(flagReasons: flagReasons, confidence: averageConfidence)
    }
    
    private func moderateUserProfile(_ profile: UserProfile) async throws -> ModerationResult {
        var allFlags: [FlagReason] = []
        var totalConfidence: Double = 0
        var checks: Int = 0
        
        // Moderate display name
        let nameResult = try await moderateText(profile.displayName)
        if case .flagged(let reasons, let confidence) = nameResult {
            allFlags.append(contentsOf: reasons)
            totalConfidence += confidence
            checks += 1
        }
        
        // Moderate bio if present
        if !profile.bio.isEmpty {
            let bioResult = try await moderateText(profile.bio)
            if case .flagged(let reasons, let confidence) = bioResult {
                allFlags.append(contentsOf: reasons)
                totalConfidence += confidence
                checks += 1
            }
        }
        
        let averageConfidence = checks > 0 ? totalConfidence / Double(checks) : 0
        
        return determineResult(flagReasons: allFlags, confidence: averageConfidence)
    }
    
    private func moderateEvent(_ event: Event) async throws -> ModerationResult {
        var allFlags: [FlagReason] = []
        var totalConfidence: Double = 0
        var checks: Int = 0
        
        // Moderate title
        let titleResult = try await moderateText(event.title)
        if case .flagged(let reasons, let confidence) = titleResult {
            allFlags.append(contentsOf: reasons)
            totalConfidence += confidence
            checks += 1
        }
        
        // Moderate description
        let descResult = try await moderateText(event.description)
        if case .flagged(let reasons, let confidence) = descResult {
            allFlags.append(contentsOf: reasons)
            totalConfidence += confidence
            checks += 1
        }
        
        // Moderate hashtags
        if !event.hashtags.isEmpty {
            let hashtagResult = try await moderateHashtags(event.hashtags)
            if case .flagged(let reasons, let confidence) = hashtagResult {
                allFlags.append(contentsOf: reasons)
                totalConfidence += confidence
                checks += 1
            }
        }
        
        let averageConfidence = checks > 0 ? totalConfidence / Double(checks) : 0
        
        return determineResult(flagReasons: allFlags, confidence: averageConfidence)
    }
    
    // MARK: - Result Determination
    
    private func determineResult(flagReasons: [FlagReason], confidence: Double) -> ModerationResult {
        guard !flagReasons.isEmpty else {
            return .approved
        }
        
        // Determine severity based on flag types
        let hasSevereFlags = flagReasons.contains { reason in
            switch reason {
            case .profanity(let severity):
                return severity == .extreme || severity == .severe
            case .inappropriateImage(let type):
                switch type {
                case .nsfw(let conf), .violence(let conf):
                    return conf > 0.9
                default:
                    return false
                }
            case .harassment, .hateSpeech, .violence:
                return true
            default:
                return false
            }
        }
        
        if hasSevereFlags || confidence > 0.9 {
            return .blocked(reasons: flagReasons, confidence: confidence)
        } else if confidence > 0.7 {
            return .requiresReview(reasons: flagReasons, confidence: confidence)
        } else {
            return .flagged(reasons: flagReasons, confidence: confidence)
        }
    }
    
    // MARK: - Caching
    
    private func getCachedResult(for content: ContentType) -> CachedModerationResult? {
        let key = generateCacheKey(for: content)
        
        return cacheQueue.sync {
            guard let cached = cache.object(forKey: key as NSString),
                  !cached.isExpired else {
                cache.removeObject(forKey: key as NSString)
                return nil
            }
            return cached
        }
    }
    
    private func cacheResult(_ result: ModerationResult, for content: ContentType) {
        let key = generateCacheKey(for: content)
        let cached = CachedModerationResult(result: result, timestamp: Date())
        
        cacheQueue.async { [weak self] in
            self?.cache.setObject(cached, forKey: key as NSString)
        }
    }
    
    private func generateCacheKey(for content: ContentType) -> String {
        let data: Data
        
        switch content {
        case .text(let text):
            data = Data(text.utf8)
        case .image(let image):
            data = image.pngData() ?? Data()
        case .url(let url):
            data = Data(url.absoluteString.utf8)
        case .hashtags(let hashtags):
            data = Data(hashtags.joined(separator: ",").utf8)
        case .userProfile(let profile):
            data = Data("\(profile.uid)_\(profile.displayName)_\(profile.bio)".utf8)
        case .event(let event):
            data = Data("\(event.id)_\(event.title)_\(event.description)".utf8)
        }
        
        return SHA256.hash(data: data).compactMap { String(format: "%02x", $0) }.joined()
    }
    
    // MARK: - Statistics and Monitoring
    
    func getStatistics() -> ModerationStatistics {
        return moderationStats
    }
    
    func clearCache() {
        cacheQueue.async { [weak self] in
            self?.cache.removeAllObjects()
            self?.logger.info("Content moderation cache cleared")
        }
    }
    
    // MARK: - Cleanup
    
    func cleanup() {
        operationQueue.cancelAllOperations()
        clearCache()
        logger.info("Enhanced content moderation service cleanup completed")
    }
}

// MARK: - Supporting Types

private class CachedModerationResult {
    let result: ModerationResult
    let timestamp: Date
    
    init(result: ModerationResult, timestamp: Date) {
        self.result = result
        self.timestamp = timestamp
    }
    
    var isExpired: Bool {
        let config = ContentModerationConfig.default
        return Date().timeIntervalSince(timestamp) > config.cacheExpiryTime
    }
}

struct ModerationStatistics {
    private(set) var totalModerations: Int = 0
    private(set) var approvedCount: Int = 0
    private(set) var flaggedCount: Int = 0
    private(set) var blockedCount: Int = 0
    private(set) var reviewRequiredCount: Int = 0
    private(set) var cacheHits: Int = 0
    private(set) var averageProcessingTime: TimeInterval = 0
    private var totalProcessingTime: TimeInterval = 0
    
    mutating func recordModeration(result: ModerationResult, processingTime: TimeInterval) {
        totalModerations += 1
        totalProcessingTime += processingTime
        averageProcessingTime = totalProcessingTime / Double(totalModerations)
        
        switch result {
        case .approved:
            approvedCount += 1
        case .flagged:
            flaggedCount += 1
        case .blocked:
            blockedCount += 1
        case .requiresReview:
            reviewRequiredCount += 1
        }
    }
    
    mutating func recordCacheHit() {
        cacheHits += 1
    }
}

enum ContentModerationError: LocalizedError {
    case serviceUnavailable
    case modelNotLoaded
    case invalidContent
    case processingFailed(Error)
    
    var errorDescription: String? {
        switch self {
        case .serviceUnavailable:
            return "Content moderation service is unavailable"
        case .modelNotLoaded:
            return "Machine learning model is not loaded"
        case .invalidContent:
            return "Content format is invalid"
        case .processingFailed(let error):
            return "Content processing failed: \(error.localizedDescription)"
        }
    }
}

// MARK: - Service Components are implemented in separate files

// EnhancedProfanityService - implemented in EnhancedProfanityService.swift
// EnhancedImageModerationService - implemented in EnhancedImageModerationService.swift  
// TextAnalysisService - implemented in TextAnalysisService.swift
// URLValidationService - implemented in URLValidationService.swift
