//
//  EnhancedImageModerationService.swift
//  Vibesy
//
//  Created by Refactoring Bot on 12/19/24.
//

import Foundation
import UIKit
import CoreML
import Vision
import Accelerate
import os.log

// MARK: - Enhanced Image Moderation Service

final class EnhancedImageModerationService {
    
    // MARK: - Properties
    
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "Vibesy", category: "ImageModeration")
    
    // CoreML Models
    private var nsfwModel: VNCoreMLModel?
    private var violenceModel: VNCoreMLModel?
    private var qualityModel: VNCoreMLModel?
    
    // Performance optimization
    private let processingQueue = DispatchQueue(label: "ImageModerationProcessing", qos: .userInitiated, attributes: .concurrent)
    private let modelLoadingQueue = DispatchQueue(label: "ModelLoading", qos: .utility)
    
    // Caching for processed results
    private let resultCache = NSCache<NSString, ImageModerationResult>()
    
    // Configuration
    private let targetImageSize = CGSize(width: 224, height: 224)
    private let jpegCompressionQuality: CGFloat = 0.8
    
    // MARK: - Initialization
    
    init() {
        configureCache()
        loadModels()
        
        logger.info("Enhanced Image Moderation Service initialized")
    }
    
    // MARK: - Public API
    
    /// Detects NSFW content in image
    func detectNSFW(_ image: UIImage) async throws -> Double? {
        return try await performImageAnalysis(image, modelType: .nsfw)
    }
    
    /// Detects violence in image
    func detectViolence(_ image: UIImage) async throws -> Double? {
        return try await performImageAnalysis(image, modelType: .violence)
    }
    
    /// Assesses overall image quality
    func assessImageQuality(_ image: UIImage) async throws -> Double {
        // Check cache first
        let cacheKey = generateImageCacheKey(image)
        if let cached = getCachedResult(cacheKey),
           let qualityScore = cached.qualityScore {
            return qualityScore
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            processingQueue.async { [weak self] in
                guard let self = self else {
                    continuation.resume(throwing: ImageModerationError.serviceUnavailable)
                    return
                }
                
                do {
                    let score = try self.calculateImageQuality(image)
                    continuation.resume(returning: score)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    /// Comprehensive image moderation check
    func moderateImage(_ image: UIImage) async throws -> ImageModerationResult {
        // Check cache first
        let cacheKey = generateImageCacheKey(image)
        if let cached = getCachedResult(cacheKey) {
            logger.debug("Using cached image moderation result")
            return cached
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            processingQueue.async { [weak self] in
                guard let self = self else {
                    continuation.resume(throwing: ImageModerationError.serviceUnavailable)
                    return
                }
                
                Task {
                    do {
                        let result = try await self.performComprehensiveModeration(image)
                        self.cacheResult(result, forKey: cacheKey)
                        continuation.resume(returning: result)
                    } catch {
                        continuation.resume(throwing: error)
                    }
                }
            }
        }
    }
    
    // MARK: - Private Implementation
    
    private enum ModelType {
        case nsfw
        case violence
        case quality
    }
    
    private func performImageAnalysis(_ image: UIImage, modelType: ModelType) async throws -> Double? {
        let model: VNCoreMLModel?
        
        switch modelType {
        case .nsfw:
            model = nsfwModel
        case .violence:
            model = violenceModel
        case .quality:
            model = qualityModel
        }
        
        guard let coreMLModel = model else {
            logger.error("CoreML model not available for type: \(modelType)")
            throw ImageModerationError.modelNotLoaded
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            processingQueue.async { [weak self] in
                guard let self = self else {
                    continuation.resume(throwing: ImageModerationError.serviceUnavailable)
                    return
                }
                
                do {
                    let score = try self.runVisionRequest(on: image, with: coreMLModel)
                    continuation.resume(returning: score)
                } catch {
                    self.logger.error("Vision request failed: \(error.localizedDescription)")
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    private func performComprehensiveModeration(_ image: UIImage) async throws -> ImageModerationResult {
        var result = ImageModerationResult(
            nsfwScore: nil,
            violenceScore: nil,
            qualityScore: nil,
            flags: [],
            confidence: 0.0,
            processingTime: 0.0
        )
        
        let startTime = CFAbsoluteTimeGetCurrent()
        
        // Run all checks concurrently
        async let nsfwTask = detectNSFW(image)
        async let violenceTask = detectViolence(image)
        async let qualityTask = assessImageQuality(image)
        
        do {
            result.nsfwScore = try await nsfwTask
            result.violenceScore = try await violenceTask
            result.qualityScore = try await qualityTask
        } catch {
            logger.warning("Some image moderation checks failed: \(error.localizedDescription)")
        }
        
        // Determine flags based on scores
        result.flags = determineFlags(from: result)
        result.confidence = calculateOverallConfidence(from: result)
        result.processingTime = CFAbsoluteTimeGetCurrent() - startTime
        
        return result
    }
    
    private func runVisionRequest(on image: UIImage, with model: VNCoreMLModel) throws -> Double? {
        guard let cgImage = image.cgImage else {
            throw ImageModerationError.invalidImage
        }
        
        var result: Double?
        let semaphore = DispatchSemaphore(value: 0)
        var requestError: Error?
        
        let request = VNCoreMLRequest(model: model) { request, error in
            defer { semaphore.signal() }
            
            if let error = error {
                requestError = error
                return
            }
            
            if let observations = request.results as? [VNClassificationObservation],
               let topResult = observations.first {
                result = Double(topResult.confidence)
            } else if let observations = request.results as? [VNPixelBufferObservation] {
                // Handle different model output types
                result = self.extractConfidenceFromPixelBuffer(observations)
            }
        }
        
        // Configure request
        request.imageCropAndScaleOption = .centerCrop
        
        let requestHandler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        
        try requestHandler.perform([request])
        semaphore.wait()
        
        if let error = requestError {
            throw error
        }
        
        return result
    }
    
    private func extractConfidenceFromPixelBuffer(_ observations: [VNPixelBufferObservation]) -> Double? {
        // Handle custom model outputs that return pixel buffers
        guard let observation = observations.first else { return nil }
        
        // This would depend on the specific model output format
        // Placeholder implementation
        return 0.0
    }
    
    private func calculateImageQuality(_ image: UIImage) throws -> Double {
        guard let cgImage = image.cgImage else {
            throw ImageModerationError.invalidImage
        }
        
        // Multi-factor quality assessment
        var qualityScore: Double = 0.0
        
        // 1. Resolution check (25% weight)
        let resolutionScore = assessResolution(cgImage)
        qualityScore += resolutionScore * 0.25
        
        // 2. Blur detection (25% weight)
        let sharpnessScore = assessSharpness(cgImage)
        qualityScore += sharpnessScore * 0.25
        
        // 3. Brightness/Contrast (25% weight)
        let exposureScore = assessExposure(cgImage)
        qualityScore += exposureScore * 0.25
        
        // 4. Noise level (25% weight)
        let noiseScore = assessNoise(cgImage)
        qualityScore += noiseScore * 0.25
        
        return min(max(qualityScore, 0.0), 1.0)
    }
    
    // MARK: - Image Quality Assessment Methods
    
    private func assessResolution(_ cgImage: CGImage) -> Double {
        let width = cgImage.width
        let height = cgImage.height
        let totalPixels = width * height
        
        // Score based on total pixels
        // Excellent: > 2MP, Good: > 1MP, Fair: > 0.3MP, Poor: < 0.3MP
        switch totalPixels {
        case 2_000_000...: return 1.0
        case 1_000_000...1_999_999: return 0.8
        case 300_000...999_999: return 0.6
        case 100_000...299_999: return 0.4
        default: return 0.2
        }
    }
    
    private func assessSharpness(_ cgImage: CGImage) -> Double {
        // Implement Laplacian variance for blur detection
        guard let dataProvider = cgImage.dataProvider,
              let data = dataProvider.data,
              let bytes = CFDataGetBytePtr(data) else {
            return 0.5 // Default score if can't assess
        }
        
        let width = cgImage.width
        let height = cgImage.height
        let bytesPerPixel = 4 // Assuming RGBA
        
        var laplacianSum: Double = 0.0
        var pixelCount = 0
        
        // Apply Laplacian kernel to detect edges
        for y in 1..<(height-1) {
            for x in 1..<(width-1) {
                let pixelIndex = (y * width + x) * bytesPerPixel
                
                // Get surrounding pixels (simplified grayscale conversion)
                let center = Double(bytes[pixelIndex])
                let top = Double(bytes[(y-1) * width * bytesPerPixel + x * bytesPerPixel])
                let bottom = Double(bytes[(y+1) * width * bytesPerPixel + x * bytesPerPixel])
                let left = Double(bytes[y * width * bytesPerPixel + (x-1) * bytesPerPixel])
                let right = Double(bytes[y * width * bytesPerPixel + (x+1) * bytesPerPixel])
                
                // Laplacian approximation: -4*center + top + bottom + left + right
                let laplacian = abs(-4 * center + top + bottom + left + right)
                laplacianSum += laplacian
                pixelCount += 1
            }
        }
        
        let variance = laplacianSum / Double(pixelCount)
        
        // Normalize to 0-1 range (values above 100 are considered sharp)
        return min(variance / 100.0, 1.0)
    }
    
    private func assessExposure(_ cgImage: CGImage) -> Double {
        guard let dataProvider = cgImage.dataProvider,
              let data = dataProvider.data,
              let bytes = CFDataGetBytePtr(data) else {
            return 0.5
        }
        
        let width = cgImage.width
        let height = cgImage.height
        let bytesPerPixel = 4
        let totalPixels = width * height
        
        var brightnessSum: Double = 0.0
        var underexposed = 0
        var overexposed = 0
        
        for i in stride(from: 0, to: totalPixels * bytesPerPixel, by: bytesPerPixel) {
            let r = Double(bytes[i])
            let g = Double(bytes[i + 1])
            let b = Double(bytes[i + 2])
            
            // Calculate luminance
            let luminance = 0.299 * r + 0.587 * g + 0.114 * b
            brightnessSum += luminance
            
            if luminance < 25 { underexposed += 1 }
            if luminance > 230 { overexposed += 1 }
        }
        
        let averageBrightness = brightnessSum / Double(totalPixels)
        let underexposedRatio = Double(underexposed) / Double(totalPixels)
        let overexposedRatio = Double(overexposed) / Double(totalPixels)
        
        // Penalize images that are too dark, too bright, or have too much clipping
        var exposureScore = 1.0
        
        if averageBrightness < 50 || averageBrightness > 200 {
            exposureScore *= 0.5
        }
        
        if underexposedRatio > 0.1 || overexposedRatio > 0.1 {
            exposureScore *= 0.7
        }
        
        return exposureScore
    }
    
    private func assessNoise(_ cgImage: CGImage) -> Double {
        // Simplified noise assessment
        // In a real implementation, you'd analyze local variance patterns
        
        guard let dataProvider = cgImage.dataProvider,
              let data = dataProvider.data,
              let bytes = CFDataGetBytePtr(data) else {
            return 0.5
        }
        
        let width = cgImage.width
        let height = cgImage.height
        let bytesPerPixel = 4
        
        var varianceSum: Double = 0.0
        var regionCount = 0
        
        // Sample 3x3 regions throughout the image
        let step = 10
        for y in stride(from: step, to: height - step, by: step) {
            for x in stride(from: step, to: width - step, by: step) {
                var regionSum: Double = 0.0
                var regionPixels = 0
                
                // Calculate mean for 3x3 region
                for dy in -1...1 {
                    for dx in -1...1 {
                        let pixelIndex = ((y + dy) * width + (x + dx)) * bytesPerPixel
                        let luminance = 0.299 * Double(bytes[pixelIndex]) +
                                      0.587 * Double(bytes[pixelIndex + 1]) +
                                      0.114 * Double(bytes[pixelIndex + 2])
                        regionSum += luminance
                        regionPixels += 1
                    }
                }
                
                let regionMean = regionSum / Double(regionPixels)
                
                // Calculate variance for region
                var variance: Double = 0.0
                for dy in -1...1 {
                    for dx in -1...1 {
                        let pixelIndex = ((y + dy) * width + (x + dx)) * bytesPerPixel
                        let luminance = 0.299 * Double(bytes[pixelIndex]) +
                                      0.587 * Double(bytes[pixelIndex + 1]) +
                                      0.114 * Double(bytes[pixelIndex + 2])
                        variance += pow(luminance - regionMean, 2)
                    }
                }
                
                varianceSum += variance / Double(regionPixels)
                regionCount += 1
            }
        }
        
        let averageVariance = varianceSum / Double(regionCount)
        
        // Lower variance suggests less noise (higher quality)
        // Normalize to 0-1 range where lower noise = higher score
        return max(0.0, 1.0 - (averageVariance / 1000.0))
    }
    
    // MARK: - Result Processing
    
    private func determineFlags(from result: ImageModerationResult) -> [ImageModerationFlag] {
        var flags: [ImageModerationFlag] = []
        
        if let nsfwScore = result.nsfwScore, nsfwScore > 0.7 {
            flags.append(.nsfw(confidence: nsfwScore))
        }
        
        if let violenceScore = result.violenceScore, violenceScore > 0.8 {
            flags.append(.violence(confidence: violenceScore))
        }
        
        if let qualityScore = result.qualityScore, qualityScore < 0.3 {
            flags.append(.lowQuality(confidence: 1.0 - qualityScore))
        }
        
        return flags
    }
    
    private func calculateOverallConfidence(from result: ImageModerationResult) -> Double {
        var confidenceSum: Double = 0.0
        var scoreCount = 0
        
        if let nsfwScore = result.nsfwScore {
            confidenceSum += nsfwScore
            scoreCount += 1
        }
        
        if let violenceScore = result.violenceScore {
            confidenceSum += violenceScore
            scoreCount += 1
        }
        
        if let qualityScore = result.qualityScore {
            confidenceSum += qualityScore
            scoreCount += 1
        }
        
        return scoreCount > 0 ? confidenceSum / Double(scoreCount) : 0.0
    }
    
    // MARK: - Model Loading
    
    private func loadModels() {
        modelLoadingQueue.async { [weak self] in
            self?.loadNSFWModel()
            self?.loadViolenceModel()
            self?.loadQualityModel()
        }
    }
    
    private func loadNSFWModel() {
        guard let modelURL = Bundle.main.url(forResource: "NSFWClassifier", withExtension: "mlmodelc") else {
            logger.warning("NSFW model not found in bundle")
            return
        }
        
        do {
            let model = try VNCoreMLModel(for: MLModel(contentsOf: modelURL))
            self.nsfwModel = model
            logger.info("NSFW model loaded successfully")
        } catch {
            logger.error("Failed to load NSFW model: \(error.localizedDescription)")
        }
    }
    
    private func loadViolenceModel() {
        guard let modelURL = Bundle.main.url(forResource: "ViolenceClassifier", withExtension: "mlmodelc") else {
            logger.warning("Violence model not found in bundle")
            return
        }
        
        do {
            let model = try VNCoreMLModel(for: MLModel(contentsOf: modelURL))
            self.violenceModel = model
            logger.info("Violence model loaded successfully")
        } catch {
            logger.error("Failed to load violence model: \(error.localizedDescription)")
        }
    }
    
    private func loadQualityModel() {
        // Quality assessment is done algorithmically, no ML model needed
        logger.info("Image quality assessment ready")
    }
    
    // MARK: - Caching
    
    private func configureCache() {
        resultCache.countLimit = 100
        resultCache.totalCostLimit = 50 * 1024 * 1024 // 50MB
    }
    
    private func generateImageCacheKey(_ image: UIImage) -> String {
        // Generate a hash based on image data for caching
        guard let data = image.jpegData(compressionQuality: 0.1) else {
            return UUID().uuidString
        }
        
        return data.base64EncodedString().prefix(32).description
    }
    
    private func getCachedResult(_ key: String) -> ImageModerationResult? {
        return resultCache.object(forKey: key as NSString)
    }
    
    private func cacheResult(_ result: ImageModerationResult, forKey key: String) {
        resultCache.setObject(result, forKey: key as NSString)
    }
}

// MARK: - Supporting Types

struct ImageModerationResult {
    var nsfwScore: Double?
    var violenceScore: Double?
    var qualityScore: Double?
    var flags: [ImageModerationFlag]
    var confidence: Double
    var processingTime: TimeInterval
}

enum ImageModerationFlag {
    case nsfw(confidence: Double)
    case violence(confidence: Double)
    case lowQuality(confidence: Double)
    case inappropriate(confidence: Double)
}

enum ImageModerationError: LocalizedError {
    case serviceUnavailable
    case modelNotLoaded
    case invalidImage
    case processingFailed(Error)
    
    var errorDescription: String? {
        switch self {
        case .serviceUnavailable:
            return "Image moderation service is unavailable"
        case .modelNotLoaded:
            return "CoreML model is not loaded"
        case .invalidImage:
            return "Image format is invalid or unsupported"
        case .processingFailed(let error):
            return "Image processing failed: \(error.localizedDescription)"
        }
    }
}