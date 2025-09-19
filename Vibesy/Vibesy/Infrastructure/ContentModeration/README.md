# Enhanced Content Moderation System

A comprehensive, high-performance content moderation system for iOS applications built with Swift. This system provides real-time content filtering, image analysis, text processing, and URL validation with support for multiple languages and customizable policies.

## Overview

The Enhanced Content Moderation System integrates multiple filtering mechanisms to provide comprehensive content analysis:

- **Text Analysis**: Profanity filtering, harassment detection, spam identification, and PII detection
- **Image Moderation**: NSFW detection, violence screening, and quality assessment using CoreML
- **URL Validation**: Malicious link detection, phishing prevention, and scam identification
- **Multi-language Support**: Configurable language-specific filtering rules
- **Performance Optimization**: Built-in caching, concurrent processing, and queue management

## Architecture

```
EnhancedContentModerationService (Main Service)
├── EnhancedProfanityService (Text filtering)
├── EnhancedImageModerationService (Image analysis)
├── TextAnalysisService (NLP processing)
└── URLValidationService (Link validation)
```

## Key Features

### 🚀 **High Performance**
- Concurrent processing of multiple content items
- Intelligent caching with configurable expiry
- Queue-based processing with priority management
- Memory-efficient operations

### 🌍 **Multi-language Support**
- Support for 10+ languages including English, Spanish, French, German, Italian, Portuguese, Russian, Polish, Japanese, and Chinese
- Language-specific profanity detection
- Automatic language detection using NaturalLanguage framework

### 🛡️ **Comprehensive Filtering**
- Profanity filtering with severity classification (mild, moderate, severe, extreme)
- Harassment and hate speech detection
- Spam pattern recognition
- Personal information (PII) detection
- NSFW image classification
- Violence detection in images
- Image quality assessment
- Malicious URL detection
- Phishing and scam prevention

### 📊 **Analytics and Monitoring**
- Built-in statistics tracking
- Performance metrics collection
- Cache hit rate monitoring
- Processing time analysis

### ⚙️ **Highly Configurable**
- Adjustable confidence thresholds
- Custom keyword lists
- Configurable cache settings
- Flexible moderation policies

## Installation

Add the content moderation files to your iOS project:

```
Infrastructure/ContentModeration/
├── EnhancedContentModerationService.swift
├── EnhancedProfanityService.swift
├── EnhancedImageModerationService.swift
├── TextAnalysisService.swift
├── URLValidationService.swift
└── ContentModerationIntegrationGuide.swift
```

## Quick Start

### Basic Usage

```swift
import Foundation

// Initialize the service
let moderationService = EnhancedContentModerationService.shared

// Moderate text content
let textResult = try await moderationService.moderateContent(.text("Sample text"))

// Moderate image content
if let image = UIImage(named: "sample") {
    let imageResult = try await moderationService.moderateContent(.image(image))
}

// Handle results
switch textResult {
case .approved:
    print("Content approved")
case .flagged(let reasons, let confidence):
    print("Content flagged: \(reasons) with confidence: \(confidence)")
case .blocked(let reasons, let confidence):
    print("Content blocked: \(reasons) with confidence: \(confidence)")
case .requiresReview(let reasons, let confidence):
    print("Content requires manual review: \(reasons)")
}
```

### Batch Processing

```swift
let contents: [ContentType] = [
    .text("First text sample"),
    .text("Second text sample"),
    .hashtags(["example", "hashtags"]),
    .image(sampleImage)
]

let results = try await moderationService.moderateContentBatch(contents)

for (index, result) in results.enumerated() {
    print("Content \(index): \(result)")
}
```

### Real-time Validation

```swift
class ContentViewModel: ObservableObject {
    @Published var validationState: ValidationState = .idle
    private let moderationService = EnhancedContentModerationService.shared
    
    func validateContent(_ text: String) {
        validationState = .validating
        
        Task {
            do {
                let result = try await moderationService.moderateContent(.text(text))
                await MainActor.run {
                    self.validationState = .validated(result)
                }
            } catch {
                await MainActor.run {
                    self.validationState = .error(error)
                }
            }
        }
    }
}
```

## Configuration

### Custom Thresholds

```swift
struct ContentModerationConfig {
    let profanityThreshold: Double = 0.7
    let harassmentThreshold: Double = 0.6
    let spamThreshold: Double = 0.8
    let nsfwThreshold: Double = 0.7
    let violenceThreshold: Double = 0.8
}
```

### Language Support

The system supports multiple languages with automatic detection:

- English (en)
- Spanish (es)
- French (fr)
- German (de)
- Italian (it)
- Portuguese (pt)
- Russian (ru)
- Polish (pl)
- Japanese (ja)
- Chinese (zh)

### Cache Configuration

```swift
// Cache settings in ContentModerationConfig
let enableCaching: Bool = true
let cacheExpiryTime: TimeInterval = 3600 // 1 hour
let maxCacheSize: Int = 1000
```

## Content Types

The system supports various content types:

```swift
enum ContentType {
    case text(String)                    // Text content
    case image(UIImage)                  // Images
    case url(URL)                        // URLs and links
    case hashtags([String])              // Hashtag arrays
    case userProfile(UserProfile)        // User profiles
    case event(Event)                    // Event content
}
```

## Moderation Results

```swift
enum ModerationResult {
    case approved                                           // Content is safe
    case flagged(reasons: [FlagReason], confidence: Double) // Content has issues but may be acceptable
    case blocked(reasons: [FlagReason], confidence: Double) // Content should be blocked
    case requiresReview(reasons: [FlagReason], confidence: Double) // Manual review needed
}
```

## Flag Reasons

The system provides detailed flagging reasons:

```swift
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
```

## Advanced Features

### Custom Profanity Lists

Add your own profanity wordlists to the app bundle:

```
profanity_en.txt    // English
profanity_es.txt    // Spanish
profanity_fr.txt    // French
// ... other languages
```

### CoreML Models

For image moderation, add CoreML models to your bundle:

```
NSFWClassifier.mlmodelc      // NSFW detection model
ViolenceClassifier.mlmodelc  // Violence detection model
```

### Performance Monitoring

```swift
let stats = moderationService.getStatistics()
print("Total moderations: \(stats.totalModerations)")
print("Average processing time: \(stats.averageProcessingTime)")
print("Cache hit rate: \(Double(stats.cacheHits) / Double(stats.totalModerations))")
```

## Best Practices

### 1. Real-time Validation
- Implement debouncing for text input validation
- Use visual indicators to show validation state
- Provide immediate feedback to users

### 2. Error Handling
- Always handle network failures gracefully
- Provide fallback validation for offline scenarios
- Log errors for monitoring and debugging

### 3. User Experience
- Show clear, actionable error messages
- Allow users to edit and resubmit content
- Consider progressive disclosure for detailed feedback

### 4. Performance
- Use batch processing for multiple items
- Leverage caching for repeated content
- Monitor processing times and optimize accordingly

### 5. Privacy and Security
- Handle user content securely
- Implement proper data retention policies
- Ensure sensitive content isn't logged

## Integration with SwiftUI

```swift
struct ContentInputView: View {
    @State private var text = ""
    @State private var validationState: ValidationState = .idle
    
    var body: some View {
        VStack {
            TextField("Enter text", text: $text)
                .onChange(of: text) { newValue in
                    validateContent(newValue)
                }
            
            ValidationIndicatorView(state: validationState)
        }
    }
    
    private func validateContent(_ content: String) {
        // Implement validation logic
    }
}
```

## Testing

### Unit Tests
```swift
func testProfanityDetection() async throws {
    let service = EnhancedContentModerationService.shared
    let result = try await service.moderateContent(.text("inappropriate content"))
    
    XCTAssertEqual(result, .flagged)
}
```

### Integration Tests
```swift
func testBatchModeration() async throws {
    let contents: [ContentType] = [/* test content */]
    let results = try await service.moderateContentBatch(contents)
    
    XCTAssertEqual(results.count, contents.count)
}
```

## Monitoring and Analytics

Track key metrics:

- **Moderation Rate**: Total content processed per time period
- **Flag Rate**: Percentage of content flagged or blocked  
- **Processing Time**: Average time per moderation request
- **Cache Performance**: Hit rate and memory usage
- **Error Rate**: Failed moderation attempts

## Troubleshooting

### Common Issues

1. **Slow Processing**: Check network connectivity and model loading status
2. **High Memory Usage**: Verify cache configuration and clear if needed
3. **False Positives**: Adjust confidence thresholds or customize wordlists
4. **Language Detection Issues**: Ensure sufficient text length for accurate detection

### Debugging

Enable detailed logging:

```swift
// The system uses os.log for debugging
// Filter logs by category: "ContentModeration", "ProfanityFilter", "ImageModeration"
```

## Contributing

When extending the system:

1. Maintain consistent error handling patterns
2. Add comprehensive unit tests
3. Update documentation for new features
4. Follow existing code style and patterns
5. Consider performance implications

## Requirements

- iOS 14.0+
- Xcode 13.0+
- Swift 5.5+

## Frameworks Used

- Foundation
- UIKit/SwiftUI
- CoreML
- Vision
- NaturalLanguage
- Network
- Accelerate
- CryptoKit

## License

This content moderation system is part of the Vibesy iOS application codebase.

---

For detailed implementation examples, see `ContentModerationIntegrationGuide.swift`.