//
//  EnhancedProfanityService.swift
//  Vibesy
//
//  Created by Refactoring Bot on 12/19/24.
//

import Foundation
import NaturalLanguage
import os.log

// MARK: - Enhanced Profanity Service

final class EnhancedProfanityService {
    
    // MARK: - Properties
    
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "Vibesy", category: "ProfanityFilter")
    
    // Enhanced profanity detection with multiple wordlists and severity levels
    private var profanityWordlists: [String: Set<String>] = [:]
    private var severityMappings: [String: ProfanitySeverity] = [:]
    
    // Language detection
    private let languageRecognizer = NLLanguageRecognizer()
    
    // Performance caching
    private let wordCache = NSCache<NSString, NSNumber>()
    private let processingQueue = DispatchQueue(label: "ProfanityProcessing", qos: .userInitiated)
    
    // MARK: - Initialization
    
    init() {
        setupWordlists()
        setupSeverityMappings()
        configureCache()
        
        logger.info("Enhanced Profanity Service initialized with multilingual support")
    }
    
    // MARK: - Public API
    
    /// Checks text for profanity with severity classification
    func checkProfanity(_ text: String) async throws -> (reason: FlagReason, confidence: Double)? {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }
        
        return await withCheckedContinuation { continuation in
            processingQueue.async { [weak self] in
                guard let self = self else {
                    continuation.resume(returning: nil)
                    return
                }
                
                let result = self.performProfanityCheck(text)
                continuation.resume(returning: result)
            }
        }
    }
    
    /// Checks profanity for a specific language
    func checkProfanity(_ text: String, language: String) async throws -> (reason: FlagReason, confidence: Double)? {
        return await withCheckedContinuation { continuation in
            processingQueue.async { [weak self] in
                guard let self = self else {
                    continuation.resume(returning: nil)
                    return
                }
                
                let result = self.performLanguageSpecificCheck(text, language: language)
                continuation.resume(returning: result)
            }
        }
    }
    
    /// Gets masked version of text with profanity replaced
    func getMaskedText(_ text: String) async -> String {
        return await withCheckedContinuation { continuation in
            processingQueue.async { [weak self] in
                guard let self = self else {
                    continuation.resume(returning: text)
                    return
                }
                
                let masked = self.maskProfaneWords(text)
                continuation.resume(returning: masked)
            }
        }
    }
    
    // MARK: - Private Implementation
    
    private func performProfanityCheck(_ text: String) -> (reason: FlagReason, confidence: Double)? {
        let normalizedText = normalizeText(text)
        let detectedLanguage = detectLanguage(normalizedText)
        
        // Check against appropriate wordlists
        var highestSeverity: ProfanitySeverity = .mild
        var matchCount = 0
        var totalWords = 0
        
        let words = tokenizeText(normalizedText)
        totalWords = words.count
        
        for word in words {
            if let severity = checkWordProfanity(word, language: detectedLanguage) {
                matchCount += 1
                if severity.rawValue > highestSeverity.rawValue {
                    highestSeverity = severity
                }
            }
        }
        
        guard matchCount > 0 else { return nil }
        
        // Calculate confidence based on match ratio and severity
        let matchRatio = Double(matchCount) / max(Double(totalWords), 1.0)
        let baseConfidence = min(matchRatio * 2.0, 1.0) // Scale up for detection
        
        // Adjust confidence based on severity
        let severityMultiplier = getSeverityMultiplier(highestSeverity)
        let finalConfidence = min(baseConfidence * severityMultiplier, 1.0)
        
        logger.debug("Profanity detected: \(matchCount)/\(totalWords) words, severity: \(highestSeverity), confidence: \(finalConfidence)")
        
        return (reason: .profanity(severity: highestSeverity), confidence: finalConfidence)
    }
    
    private func performLanguageSpecificCheck(_ text: String, language: String) -> (reason: FlagReason, confidence: Double)? {
        let normalizedText = normalizeText(text)
        let words = tokenizeText(normalizedText)
        
        var matchCount = 0
        var highestSeverity: ProfanitySeverity = .mild
        
        for word in words {
            if let severity = checkWordInLanguage(word, language: language) {
                matchCount += 1
                if severity.rawValue > highestSeverity.rawValue {
                    highestSeverity = severity
                }
            }
        }
        
        guard matchCount > 0 else { return nil }
        
        let confidence = Double(matchCount) / Double(words.count)
        return (reason: .profanity(severity: highestSeverity), confidence: confidence)
    }
    
    private func maskProfaneWords(_ text: String) -> String {
        let normalizedText = normalizeText(text)
        let language = detectLanguage(normalizedText)
        var maskedText = text
        
        let words = text.components(separatedBy: .whitespacesAndNewlines)
        
        for word in words {
            let cleanWord = word.trimmingCharacters(in: .punctuationCharacters)
            if checkWordProfanity(cleanWord.lowercased(), language: language) != nil {
                let mask = String(repeating: "*", count: max(cleanWord.count - 1, 1)) + cleanWord.suffix(1)
                maskedText = maskedText.replacingOccurrences(of: word, with: mask)
            }
        }
        
        return maskedText
    }
    
    // MARK: - Text Processing Helpers
    
    private func normalizeText(_ text: String) -> String {
        return text
            .lowercased()
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: nil)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    private func tokenizeText(_ text: String) -> [String] {
        let tokenizer = NLTokenizer(unit: .word)
        tokenizer.string = text
        
        var tokens: [String] = []
        tokenizer.enumerateTokens(in: text.startIndex..<text.endIndex) { tokenRange, _ in
            let token = String(text[tokenRange])
                .trimmingCharacters(in: .punctuationCharacters)
                .lowercased()
            
            if !token.isEmpty {
                tokens.append(token)
            }
            return true
        }
        
        return tokens
    }
    
    private func detectLanguage(_ text: String) -> String {
        languageRecognizer.processString(text)
        
        if let dominantLanguage = languageRecognizer.dominantLanguage {
            return dominantLanguage.rawValue
        }
        
        return "en" // Default to English
    }
    
    // MARK: - Word Checking
    
    private func checkWordProfanity(_ word: String, language: String) -> ProfanitySeverity? {
        // Check cache first
        let cacheKey = "\(language)_\(word)" as NSString
        if let cachedSeverity = wordCache.object(forKey: cacheKey) {
            let severityValue = cachedSeverity.intValue
            return severityValue >= 0 ? ProfanitySeverity(rawValue: severityValue) : nil
        }
        
        // Check language-specific wordlist
        let severity = checkWordInLanguage(word, language: language)
        
        // Cache result (use -1 for no match)
        let cacheValue = severity?.rawValue ?? -1
        wordCache.setObject(NSNumber(value: cacheValue), forKey: cacheKey)
        
        return severity
    }
    
    private func checkWordInLanguage(_ word: String, language: String) -> ProfanitySeverity? {
        // Check exact matches first
        if let wordlist = profanityWordlists[language], wordlist.contains(word) {
            return severityMappings[word] ?? .moderate
        }
        
        // Check default English wordlist if language-specific not found
        if language != "en", let englishWordlist = profanityWordlists["en"], englishWordlist.contains(word) {
            return severityMappings[word] ?? .moderate
        }
        
        // Check for partial matches and variants
        return checkWordVariants(word, language: language)
    }
    
    private func checkWordVariants(_ word: String, language: String) -> ProfanitySeverity? {
        guard word.count > 2 else { return nil }
        
        let wordlist = profanityWordlists[language] ?? profanityWordlists["en"] ?? Set<String>()
        
        // Check if word contains profane substrings
        for profaneWord in wordlist {
            if word.contains(profaneWord) || profaneWord.contains(word) {
                let severity = severityMappings[profaneWord] ?? .mild
                return severity
            }
        }
        
        // Check Levenshtein distance for typos
        for profaneWord in wordlist {
            if levenshteinDistance(word, profaneWord) <= 1 && word.count >= profaneWord.count - 1 {
                return severityMappings[profaneWord] ?? .mild
            }
        }
        
        return nil
    }
    
    // MARK: - Setup Methods
    
    private func setupWordlists() {
        // Load profanity wordlists from bundle or initialize with basic sets
        profanityWordlists = loadProfanityWordlists()
        
        logger.info("Loaded profanity wordlists for \(profanityWordlists.keys.count) languages")
    }
    
    private func loadProfanityWordlists() -> [String: Set<String>] {
        var wordlists: [String: Set<String>] = [:]
        
        let languages = ["en", "es", "fr", "de", "it", "pt", "ru", "pl", "ja", "zh"]
        
        for language in languages {
            if let words = loadWordlistForLanguage(language) {
                wordlists[language] = Set(words)
            }
        }
        
        // Ensure English has at least basic words
        if wordlists["en"] == nil {
            wordlists["en"] = getBasicEnglishProfanity()
        }
        
        return wordlists
    }
    
    private func loadWordlistForLanguage(_ language: String) -> [String]? {
        // Try to load from bundle
        guard let path = Bundle.main.path(forResource: "profanity_\(language)", ofType: "txt"),
              let content = try? String(contentsOfFile: path) else {
            logger.debug("Could not load profanity wordlist for language: \(language)")
            return nil
        }
        
        return content
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
            .filter { !$0.isEmpty }
    }
    
    private func getBasicEnglishProfanity() -> Set<String> {
        // Basic set of common profane words for fallback
        return Set([
            // Mild profanity
            "damn", "crap", "hell",
            // Moderate profanity  
            "shit", "bitch", "ass", "piss",
            // Severe profanity would go here
            // Note: Intentionally limited set for example
        ])
    }
    
    private func setupSeverityMappings() {
        // Map specific words to severity levels
        severityMappings = [
            // Mild
            "damn": .mild,
            "crap": .mild,
            "hell": .mild,
            
            // Moderate  
            "shit": .moderate,
            "bitch": .moderate,
            "ass": .moderate,
            "piss": .moderate,
            
            // Severe and Extreme would be mapped here
            // with appropriate content
        ]
    }
    
    private func configureCache() {
        wordCache.countLimit = 10000
        wordCache.totalCostLimit = 1024 * 1024 // 1MB
    }
    
    // MARK: - Helper Functions
    
    private func getSeverityMultiplier(_ severity: ProfanitySeverity) -> Double {
        switch severity {
        case .mild: return 1.0
        case .moderate: return 1.3
        case .severe: return 1.7
        case .extreme: return 2.0
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
}

// MARK: - ProfanitySeverity Extension

extension ProfanitySeverity {
    var rawValue: Int {
        switch self {
        case .mild: return 0
        case .moderate: return 1
        case .severe: return 2
        case .extreme: return 3
        }
    }
    
    init?(rawValue: Int) {
        switch rawValue {
        case 0: self = .mild
        case 1: self = .moderate
        case 2: self = .severe
        case 3: self = .extreme
        default: return nil
        }
    }
}