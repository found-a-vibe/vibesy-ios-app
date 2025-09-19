//
//  TextAnalysisService.swift
//  Vibesy
//
//  Created by Refactoring Bot on 12/19/24.
//

import Foundation
import NaturalLanguage
import os.log

// MARK: - Text Analysis Service

final class TextAnalysisService {
    
    // MARK: - Properties
    
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "Vibesy", category: "TextAnalysis")
    
    // NLP Components
    private let sentimentAnalyzer = NLModel.sentimentAnalyzer()
    private let languageRecognizer = NLLanguageRecognizer()
    private let tagger = NLTagger(tagSchemes: [.tokenType, .language, .lexicalClass, .nameType])
    
    // Performance caching
    private let analysisCache = NSCache<NSString, TextAnalysisResult>()
    private let processingQueue = DispatchQueue(label: "TextAnalysisProcessing", qos: .userInitiated)
    
    // Pattern matching
    private let emailRegex = try! NSRegularExpression(pattern: #"[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}"#)
    private let phoneRegex = try! NSRegularExpression(pattern: #"\b(?:\+?1[-.\s]?)?(?:\(?[2-9]\d{2}\)?[-.\s]?)?[2-9]\d{2}[-.\s]?\d{4}\b"#)
    private let ssnRegex = try! NSRegularExpression(pattern: #"\b\d{3}-?\d{2}-?\d{4}\b"#)
    private let creditCardRegex = try! NSRegularExpression(pattern: #"\b(?:\d{4}[-\s]?){3}\d{4}\b"#)
    
    // Spam indicators
    private let spamKeywords = Set([
        "free", "win", "winner", "congratulations", "prize", "urgent", "act now",
        "limited time", "click here", "buy now", "discount", "offer expires",
        "make money", "work from home", "no experience", "guaranteed",
        "viagra", "cialis", "pharmacy", "weight loss", "miracle cure"
    ])
    
    private let harassmentKeywords = Set([
        "kill yourself", "die", "hate you", "loser", "idiot", "stupid",
        "worthless", "pathetic", "disgusting", "freak", "weirdo"
    ])
    
    // MARK: - Initialization
    
    init() {
        configureCache()
        logger.info("Text Analysis Service initialized")
    }
    
    // MARK: - Public API
    
    /// Sanitizes text by removing excessive whitespace and normalizing
    func sanitizeText(_ text: String) -> String {
        return text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .replacingOccurrences(of: #"[^\p{L}\p{N}\p{P}\p{S}\s]"#, with: "", options: .regularExpression)
    }
    
    /// Detects harassment patterns in text
    func detectHarassment(_ text: String) async throws -> Double? {
        return await withCheckedContinuation { continuation in
            processingQueue.async { [weak self] in
                guard let self = self else {
                    continuation.resume(returning: nil)
                    return
                }
                
                let score = self.analyzeHarassment(text)
                continuation.resume(returning: score)
            }
        }
    }
    
    /// Detects spam patterns in text
    func detectSpam(_ text: String) async throws -> Double? {
        return await withCheckedContinuation { continuation in
            processingQueue.async { [weak self] in
                guard let self = self else {
                    continuation.resume(returning: nil)
                    return
                }
                
                let score = self.analyzeSpam(text)
                continuation.resume(returning: score)
            }
        }
    }
    
    /// Checks for personal information in text
    func containsPersonalInformation(_ text: String) -> Bool {
        let lowercasedText = text.lowercased()
        
        // Check for email addresses
        if emailRegex.numberOfMatches(in: text, range: NSRange(text.startIndex..., in: text)) > 0 {
            return true
        }
        
        // Check for phone numbers
        if phoneRegex.numberOfMatches(in: text, range: NSRange(text.startIndex..., in: text)) > 0 {
            return true
        }
        
        // Check for SSNs
        if ssnRegex.numberOfMatches(in: text, range: NSRange(text.startIndex..., in: text)) > 0 {
            return true
        }
        
        // Check for credit card numbers
        if creditCardRegex.numberOfMatches(in: text, range: NSRange(text.startIndex..., in: text)) > 0 {
            return true
        }
        
        // Check for other PII patterns
        return containsOtherPII(lowercasedText)
    }
    
    /// Detects hashtag spam patterns
    func detectHashtagSpam(_ hashtags: [String]) -> Bool {
        // Too many hashtags
        if hashtags.count > 20 {
            return true
        }
        
        // Repetitive hashtags
        let uniqueHashtags = Set(hashtags.map { $0.lowercased() })
        if hashtags.count > uniqueHashtags.count * 2 {
            return true
        }
        
        // Check for spam keywords in hashtags
        let hashtagText = hashtags.joined(separator: " ").lowercased()
        for keyword in spamKeywords {
            if hashtagText.contains(keyword) {
                return true
            }
        }
        
        return false
    }
    
    /// Comprehensive text analysis
    func analyzeText(_ text: String) async -> TextAnalysisResult {
        // Check cache first
        let cacheKey = text.prefix(100).description as NSString
        if let cached = analysisCache.object(forKey: cacheKey) {
            return cached
        }
        
        return await withCheckedContinuation { continuation in
            processingQueue.async { [weak self] in
                guard let self = self else {
                    continuation.resume(returning: TextAnalysisResult())
                    return
                }
                
                let result = self.performComprehensiveAnalysis(text)
                self.analysisCache.setObject(result, forKey: cacheKey)
                continuation.resume(returning: result)
            }
        }
    }
    
    // MARK: - Private Implementation
    
    private func analyzeHarassment(_ text: String) -> Double? {
        let lowercasedText = text.lowercased()
        var harassmentScore: Double = 0.0
        var indicators = 0
        
        // Check for harassment keywords
        for keyword in harassmentKeywords {
            if lowercasedText.contains(keyword) {
                harassmentScore += 0.3
                indicators += 1
            }
        }
        
        // Check for aggressive patterns
        let exclamationCount = text.filter { $0 == "!" }.count
        if exclamationCount > 3 {
            harassmentScore += 0.1
            indicators += 1
        }
        
        let capsCount = text.filter { $0.isUppercase }.count
        let capsRatio = Double(capsCount) / Double(text.count)
        if capsRatio > 0.5 && text.count > 10 {
            harassmentScore += 0.2
            indicators += 1
        }
        
        // Sentiment analysis
        if let sentiment = analyzeSentiment(text), sentiment < -0.5 {
            harassmentScore += 0.2
            indicators += 1
        }
        
        // Check for threatening language patterns
        let threateningPatterns = [
            "i will", "gonna get", "you better", "or else", "regret it"
        ]
        
        for pattern in threateningPatterns {
            if lowercasedText.contains(pattern) {
                harassmentScore += 0.15
                indicators += 1
            }
        }
        
        return indicators > 0 ? min(harassmentScore, 1.0) : nil
    }
    
    private func analyzeSpam(_ text: String) -> Double? {
        let lowercasedText = text.lowercased()
        var spamScore: Double = 0.0
        var indicators = 0
        
        // Check for spam keywords
        let words = lowercasedText.components(separatedBy: .whitespacesAndNewlines)
        for word in words {
            if spamKeywords.contains(word) {
                spamScore += 0.1
                indicators += 1
            }
        }
        
        // Check for excessive punctuation
        let punctuationCount = text.filter { "!@#$%^&*".contains($0) }.count
        if punctuationCount > text.count / 4 {
            spamScore += 0.2
            indicators += 1
        }
        
        // Check for repetitive text
        if containsRepetitiveText(text) {
            spamScore += 0.3
            indicators += 1
        }
        
        // Check for suspicious URLs or promotional content
        if text.contains("http") || text.contains("www.") || text.contains(".com") {
            spamScore += 0.15
            indicators += 1
        }
        
        // Check for money/financial terms
        let moneyTerms = ["$", "money", "cash", "payment", "credit", "loan", "debt"]
        for term in moneyTerms {
            if lowercasedText.contains(term) {
                spamScore += 0.05
                indicators += 1
                break
            }
        }
        
        return indicators > 0 ? min(spamScore, 1.0) : nil
    }
    
    private func containsOtherPII(_ text: String) -> Bool {
        // Check for address patterns
        let addressKeywords = ["street", "st", "avenue", "ave", "road", "rd", "drive", "dr"]
        let hasAddressKeyword = addressKeywords.contains { text.contains($0) }
        let hasNumbers = text.rangeOfCharacter(from: .decimalDigits) != nil
        
        if hasAddressKeyword && hasNumbers {
            return true
        }
        
        // Check for date of birth patterns (simplified)
        let datePatterns = [
            #"\b\d{1,2}[/-]\d{1,2}[/-]\d{2,4}\b"#,
            #"\b(january|february|march|april|may|june|july|august|september|october|november|december)\s+\d{1,2},?\s+\d{2,4}\b"#
        ]
        
        for pattern in datePatterns {
            do {
                let regex = try NSRegularExpression(pattern: pattern, options: .caseInsensitive)
                if regex.numberOfMatches(in: text, range: NSRange(text.startIndex..., in: text)) > 0 {
                    return true
                }
            } catch {
                continue
            }
        }
        
        return false
    }
    
    private func containsRepetitiveText(_ text: String) -> Bool {
        let words = text.components(separatedBy: .whitespacesAndNewlines)
        let wordCount = words.count
        let uniqueWords = Set(words)
        
        // If more than 70% of words are repeated
        return Double(uniqueWords.count) / Double(wordCount) < 0.3 && wordCount > 5
    }
    
    private func analyzeSentiment(_ text: String) -> Double? {
        tagger.string = text
        
        var sentimentScore: Double = 0.0
        var tokenCount = 0
        
        tagger.enumerateTokens(in: text.startIndex..<text.endIndex) { tokenRange, _ in
            let token = String(text[tokenRange])
            
            if let prediction = try? sentimentAnalyzer?.prediction(from: token) {
                if let label = prediction.label {
                    switch label {
                    case "Pos":
                        sentimentScore += 1.0
                    case "Neg":
                        sentimentScore -= 1.0
                    default:
                        break
                    }
                    tokenCount += 1
                }
            }
            
            return true
        }
        
        return tokenCount > 0 ? sentimentScore / Double(tokenCount) : nil
    }
    
    private func performComprehensiveAnalysis(_ text: String) -> TextAnalysisResult {
        var result = TextAnalysisResult()
        
        result.wordCount = text.components(separatedBy: .whitespacesAndNewlines).count
        result.characterCount = text.count
        result.language = detectLanguage(text)
        result.sentiment = analyzeSentiment(text)
        result.containsPII = containsPersonalInformation(text)
        
        // Extract entities
        result.entities = extractEntities(text)
        
        // Calculate readability (simplified)
        result.readabilityScore = calculateReadability(text)
        
        return result
    }
    
    private func detectLanguage(_ text: String) -> String? {
        languageRecognizer.processString(text)
        return languageRecognizer.dominantLanguage?.rawValue
    }
    
    private func extractEntities(_ text: String) -> [String] {
        var entities: [String] = []
        
        tagger.string = text
        tagger.enumerateTokens(in: text.startIndex..<text.endIndex) { tokenRange, attributes in
            if let nameType = attributes[.nameType] {
                let entity = String(text[tokenRange])
                entities.append("\(nameType): \(entity)")
            }
            return true
        }
        
        return entities
    }
    
    private func calculateReadability(_ text: String) -> Double {
        // Simplified Flesch Reading Ease approximation
        let sentences = text.components(separatedBy: CharacterSet(charactersIn: ".!?")).count
        let words = text.components(separatedBy: .whitespacesAndNewlines).count
        let syllables = estimateSyllables(text)
        
        guard sentences > 0 && words > 0 else { return 0.0 }
        
        let avgWordsPerSentence = Double(words) / Double(sentences)
        let avgSyllablesPerWord = Double(syllables) / Double(words)
        
        let score = 206.835 - (1.015 * avgWordsPerSentence) - (84.6 * avgSyllablesPerWord)
        
        return max(0.0, min(100.0, score)) / 100.0
    }
    
    private func estimateSyllables(_ text: String) -> Int {
        let vowels = CharacterSet(charactersIn: "aeiouAEIOU")
        var syllableCount = 0
        var previousWasVowel = false
        
        for character in text {
            let isVowel = vowels.contains(character.unicodeScalars.first!)
            if isVowel && !previousWasVowel {
                syllableCount += 1
            }
            previousWasVowel = isVowel
        }
        
        return max(1, syllableCount)
    }
    
    // MARK: - Cache Configuration
    
    private func configureCache() {
        analysisCache.countLimit = 500
        analysisCache.totalCostLimit = 10 * 1024 * 1024 // 10MB
    }
}

// MARK: - Supporting Types

struct TextAnalysisResult {
    var wordCount: Int = 0
    var characterCount: Int = 0
    var language: String?
    var sentiment: Double?
    var containsPII: Bool = false
    var entities: [String] = []
    var readabilityScore: Double = 0.0
}