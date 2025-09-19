//
//  ContentModerationIntegrationGuide.swift
//  Vibesy
//
//  Created by Refactoring Bot on 12/19/24.
//
//  This file provides practical examples for integrating the Enhanced Content Moderation System
//  into your iOS application with real-world scenarios and best practices.

import Foundation
import SwiftUI
import Combine
import os.log

// MARK: - Integration Examples

// MARK: Example 1: Real-time Text Validation in SwiftUI

struct ValidatedTextFieldView: View {
    @State private var text: String = ""
    @StateObject private var validator = TextValidationViewModel()
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            TextField("Enter your message", text: $text)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .onChange(of: text) { newValue in
                    validator.validateText(newValue)
                }
            
            ValidationStatusView(state: validator.validationState)
            
            Button("Post Message") {
                Task {
                    await validator.submitContent()
                }
            }
            .disabled(!validator.canSubmit)
        }
        .padding()
    }
}

// MARK: Text Validation ViewModel

@MainActor
final class TextValidationViewModel: ObservableObject {
    @Published var validationState: ValidationState = .idle
    @Published var canSubmit: Bool = false
    
    private let moderationService = EnhancedContentModerationService.shared
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "Vibesy", 
                               category: "TextValidation")
    
    private var debounceTimer: Timer?
    private let debounceDelay: TimeInterval = 0.5
    
    func validateText(_ text: String) {
        // Cancel previous timer
        debounceTimer?.invalidate()
        
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            validationState = .idle
            canSubmit = false
            return
        }
        
        validationState = .validating
        
        // Debounce validation to avoid excessive API calls
        debounceTimer = Timer.scheduledTimer(withTimeInterval: debounceDelay, repeats: false) { [weak self] _ in
            Task { [weak self] in
                await self?.performValidation(text)
            }
        }
    }
    
    private func performValidation(_ text: String) async {
        do {
            let result = try await moderationService.moderateContent(.text(text))
            
            switch result {
            case .approved:
                validationState = .valid
                canSubmit = true
                
            case .flagged(let reasons, let confidence):
                validationState = .flagged(reasons: reasons, confidence: confidence)
                canSubmit = confidence < 0.8 // Allow submission if confidence is low
                
            case .blocked(let reasons, let confidence):
                validationState = .blocked(reasons: reasons, confidence: confidence)
                canSubmit = false
                
            case .requiresReview(let reasons, let confidence):
                validationState = .requiresReview(reasons: reasons, confidence: confidence)
                canSubmit = false // Require manual approval
            }
            
        } catch {
            logger.error("Validation failed: \(error.localizedDescription)")
            validationState = .error(error)
            canSubmit = false
        }
    }
    
    func submitContent() async {
        // Implementation for submitting validated content
        logger.info("Content submitted successfully")
    }
}

// MARK: Validation State Management

enum ValidationState: Equatable {
    case idle
    case validating
    case valid
    case flagged(reasons: [FlagReason], confidence: Double)
    case blocked(reasons: [FlagReason], confidence: Double)
    case requiresReview(reasons: [FlagReason], confidence: Double)
    case error(Error)
    
    static func == (lhs: ValidationState, rhs: ValidationState) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle), (.validating, .validating), (.valid, .valid):
            return true
        case (.flagged(let lReasons, let lConf), .flagged(let rReasons, let rConf)):
            return lReasons.count == rReasons.count && lConf == rConf
        case (.blocked(let lReasons, let lConf), .blocked(let rReasons, let rConf)):
            return lReasons.count == rReasons.count && lConf == rConf
        case (.requiresReview(let lReasons, let lConf), .requiresReview(let rReasons, let rConf)):
            return lReasons.count == rReasons.count && lConf == rConf
        default:
            return false
        }
    }
}

// MARK: Validation Status View

struct ValidationStatusView: View {
    let state: ValidationState
    
    var body: some View {
        HStack {
            Image(systemName: iconName)
                .foregroundColor(iconColor)
            
            Text(statusMessage)
                .font(.caption)
                .foregroundColor(textColor)
            
            Spacer()
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(backgroundColor.opacity(0.1))
        .cornerRadius(8)
    }
    
    private var iconName: String {
        switch state {
        case .idle:
            return "circle"
        case .validating:
            return "clock"
        case .valid:
            return "checkmark.circle.fill"
        case .flagged:
            return "exclamationmark.triangle.fill"
        case .blocked:
            return "xmark.circle.fill"
        case .requiresReview:
            return "eye.fill"
        case .error:
            return "exclamationmark.circle.fill"
        }
    }
    
    private var iconColor: Color {
        switch state {
        case .idle:
            return .gray
        case .validating:
            return .blue
        case .valid:
            return .green
        case .flagged:
            return .orange
        case .blocked, .error:
            return .red
        case .requiresReview:
            return .purple
        }
    }
    
    private var statusMessage: String {
        switch state {
        case .idle:
            return "Ready to validate"
        case .validating:
            return "Checking content..."
        case .valid:
            return "Content looks good!"
        case .flagged(let reasons, let confidence):
            return "Content may have issues (\(Int(confidence * 100))% confidence)"
        case .blocked(let reasons, let confidence):
            return "Content blocked: \(formatReasons(reasons))"
        case .requiresReview(let reasons, let confidence):
            return "Content requires manual review: \(formatReasons(reasons))"
        case .error:
            return "Validation error occurred"
        }
    }
    
    private var textColor: Color {
        switch state {
        case .idle:
            return .gray
        case .validating:
            return .blue
        case .valid:
            return .green
        case .flagged:
            return .orange
        case .blocked, .error:
            return .red
        case .requiresReview:
            return .purple
        }
    }
    
    private var backgroundColor: Color {
        textColor
    }
    
    private func formatReasons(_ reasons: [FlagReason]) -> String {
        return reasons.prefix(2).map { reasonDescription($0) }.joined(separator: ", ")
    }
    
    private func reasonDescription(_ reason: FlagReason) -> String {
        switch reason {
        case .profanity(let severity):
            return "profanity (\(severity))"
        case .harassment:
            return "harassment"
        case .spam:
            return "spam"
        case .personalInformation:
            return "personal information"
        default:
            return "inappropriate content"
        }
    }
}

// MARK: Example 2: Image Upload with Moderation

struct ImageUploadView: View {
    @State private var selectedImage: UIImage?
    @State private var moderationResult: ImageModerationResult?
    @State private var isAnalyzing = false
    @State private var showingImagePicker = false
    
    private let moderationService = EnhancedContentModerationService.shared
    
    var body: some View {
        VStack(spacing: 20) {
            if let image = selectedImage {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxHeight: 300)
                    .cornerRadius(12)
            } else {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.gray.opacity(0.3))
                    .frame(height: 200)
                    .overlay(
                        Text("Tap to select image")
                            .foregroundColor(.gray)
                    )
            }
            
            Button("Select Image") {
                showingImagePicker = true
            }
            .buttonStyle(.borderedProminent)
            
            if isAnalyzing {
                ProgressView("Analyzing image...")
            } else if let result = moderationResult {
                ImageModerationResultView(result: result)
            }
            
            Button("Upload Image") {
                // Upload implementation
            }
            .disabled(selectedImage == nil || !canUpload)
            .buttonStyle(.bordered)
        }
        .padding()
        .sheet(isPresented: $showingImagePicker) {
            ImagePickerView(selectedImage: $selectedImage) { image in
                analyzeImage(image)
            }
        }
    }
    
    private var canUpload: Bool {
        guard let result = moderationResult else { return false }
        return result.flags.isEmpty || 
               result.flags.allSatisfy { flag in
                   if case .lowQuality = flag { return true }
                   return false
               }
    }
    
    private func analyzeImage(_ image: UIImage) {
        isAnalyzing = true
        moderationResult = nil
        
        Task {
            do {
                let result = try await moderationService.moderateContent(.image(image))
                
                await MainActor.run {
                    // Convert to ImageModerationResult for display
                    if case .flagged(let reasons, let confidence) = result {
                        self.moderationResult = ImageModerationResult(
                            nsfwScore: extractNSFWScore(from: reasons),
                            violenceScore: extractViolenceScore(from: reasons),
                            qualityScore: extractQualityScore(from: reasons),
                            flags: extractImageFlags(from: reasons),
                            confidence: confidence,
                            processingTime: 0.0
                        )
                    }
                    self.isAnalyzing = false
                }
                
            } catch {
                await MainActor.run {
                    self.isAnalyzing = false
                    // Handle error
                }
            }
        }
    }
    
    private func extractNSFWScore(from reasons: [FlagReason]) -> Double? {
        for reason in reasons {
            if case .inappropriateImage(.nsfw(let confidence)) = reason {
                return confidence
            }
        }
        return nil
    }
    
    private func extractViolenceScore(from reasons: [FlagReason]) -> Double? {
        for reason in reasons {
            if case .inappropriateImage(.violence(let confidence)) = reason {
                return confidence
            }
        }
        return nil
    }
    
    private func extractQualityScore(from reasons: [FlagReason]) -> Double? {
        for reason in reasons {
            if case .inappropriateImage(.lowQuality(let confidence)) = reason {
                return 1.0 - confidence
            }
        }
        return 1.0
    }
    
    private func extractImageFlags(from reasons: [FlagReason]) -> [ImageModerationFlag] {
        return reasons.compactMap { reason in
            switch reason {
            case .inappropriateImage(let type):
                switch type {
                case .nsfw(let confidence):
                    return .nsfw(confidence: confidence)
                case .violence(let confidence):
                    return .violence(confidence: confidence)
                case .lowQuality(let confidence):
                    return .lowQuality(confidence: confidence)
                case .inappropriate(let confidence):
                    return .inappropriate(confidence: confidence)
                }
            default:
                return nil
            }
        }
    }
}

// MARK: Image Moderation Result View

struct ImageModerationResultView: View {
    let result: ImageModerationResult
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Image Analysis Results")
                .font(.headline)
            
            if !result.flags.isEmpty {
                ForEach(Array(result.flags.enumerated()), id: \.offset) { index, flag in
                    HStack {
                        Image(systemName: iconForFlag(flag))
                            .foregroundColor(colorForFlag(flag))
                        
                        Text(descriptionForFlag(flag))
                            .font(.caption)
                        
                        Spacer()
                        
                        Text("\(Int(confidenceForFlag(flag) * 100))%")
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                }
            } else {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    
                    Text("Image passed all checks")
                        .font(.caption)
                }
            }
            
            Text("Processing time: \(String(format: "%.2f", result.processingTime))s")
                .font(.caption2)
                .foregroundColor(.gray)
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
    }
    
    private func iconForFlag(_ flag: ImageModerationFlag) -> String {
        switch flag {
        case .nsfw:
            return "eye.slash.fill"
        case .violence:
            return "exclamationmark.triangle.fill"
        case .lowQuality:
            return "photo.badge.plus"
        case .inappropriate:
            return "exclamationmark.circle.fill"
        }
    }
    
    private func colorForFlag(_ flag: ImageModerationFlag) -> Color {
        switch flag {
        case .nsfw, .violence, .inappropriate:
            return .red
        case .lowQuality:
            return .orange
        }
    }
    
    private func descriptionForFlag(_ flag: ImageModerationFlag) -> String {
        switch flag {
        case .nsfw:
            return "Potentially inappropriate content"
        case .violence:
            return "Violence detected"
        case .lowQuality:
            return "Low image quality"
        case .inappropriate:
            return "Inappropriate content"
        }
    }
    
    private func confidenceForFlag(_ flag: ImageModerationFlag) -> Double {
        switch flag {
        case .nsfw(let confidence), .violence(let confidence),
             .lowQuality(let confidence), .inappropriate(let confidence):
            return confidence
        }
    }
}

// MARK: Example 3: Event Creation with Comprehensive Moderation

struct EventCreationView: View {
    @State private var title = ""
    @State private var description = ""
    @State private var hashtags = ""
    @State private var eventImage: UIImage?
    
    @StateObject private var moderationManager = EventModerationManager()
    
    var body: some View {
        NavigationView {
            Form {
                Section("Event Details") {
                    TextField("Title", text: $title)
                        .onChange(of: title) { moderationManager.validateTitle($0) }
                    
                    TextField("Description", text: $description, axis: .vertical)
                        .lineLimit(3...6)
                        .onChange(of: description) { moderationManager.validateDescription($0) }
                    
                    TextField("Hashtags (comma separated)", text: $hashtags)
                        .onChange(of: hashtags) { moderationManager.validateHashtags($0) }
                }
                
                Section("Event Image") {
                    if let image = eventImage {
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxHeight: 200)
                    }
                    
                    Button("Select Image") {
                        // Image picker implementation
                    }
                }
                
                Section("Validation Status") {
                    ModerationStatusRow(title: "Title", state: moderationManager.titleState)
                    ModerationStatusRow(title: "Description", state: moderationManager.descriptionState)
                    ModerationStatusRow(title: "Hashtags", state: moderationManager.hashtagsState)
                    
                    if let imageState = moderationManager.imageState {
                        ModerationStatusRow(title: "Image", state: imageState)
                    }
                }
            }
            .navigationTitle("Create Event")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Create") {
                        Task {
                            await moderationManager.createEvent()
                        }
                    }
                    .disabled(!moderationManager.canCreateEvent)
                }
            }
        }
    }
}

// MARK: Event Moderation Manager

@MainActor
final class EventModerationManager: ObservableObject {
    @Published var titleState: ValidationState = .idle
    @Published var descriptionState: ValidationState = .idle
    @Published var hashtagsState: ValidationState = .idle
    @Published var imageState: ValidationState? = nil
    
    @Published var canCreateEvent = false
    
    private let moderationService = EnhancedContentModerationService.shared
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "Vibesy", 
                               category: "EventModeration")
    
    private var titleTimer: Timer?
    private var descriptionTimer: Timer?
    private var hashtagsTimer: Timer?
    
    func validateTitle(_ title: String) {
        titleTimer?.invalidate()
        titleState = .validating
        
        titleTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false) { [weak self] _ in
            Task { [weak self] in
                await self?.performTitleValidation(title)
            }
        }
    }
    
    func validateDescription(_ description: String) {
        descriptionTimer?.invalidate()
        descriptionState = .validating
        
        descriptionTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: false) { [weak self] _ in
            Task { [weak self] in
                await self?.performDescriptionValidation(description)
            }
        }
    }
    
    func validateHashtags(_ hashtags: String) {
        hashtagsTimer?.invalidate()
        hashtagsState = .validating
        
        hashtagsTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false) { [weak self] _ in
            Task { [weak self] in
                await self?.performHashtagsValidation(hashtags)
            }
        }
    }
    
    private func performTitleValidation(_ title: String) async {
        do {
            let result = try await moderationService.moderateContent(.text(title))
            titleState = mapModerationResult(result)
        } catch {
            titleState = .error(error)
        }
        updateCanCreateEvent()
    }
    
    private func performDescriptionValidation(_ description: String) async {
        do {
            let result = try await moderationService.moderateContent(.text(description))
            descriptionState = mapModerationResult(result)
        } catch {
            descriptionState = .error(error)
        }
        updateCanCreateEvent()
    }
    
    private func performHashtagsValidation(_ hashtags: String) async {
        let hashtagArray = hashtags.components(separatedBy: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        
        do {
            let result = try await moderationService.moderateContent(.hashtags(hashtagArray))
            hashtagsState = mapModerationResult(result)
        } catch {
            hashtagsState = .error(error)
        }
        updateCanCreateEvent()
    }
    
    private func mapModerationResult(_ result: ModerationResult) -> ValidationState {
        switch result {
        case .approved:
            return .valid
        case .flagged(let reasons, let confidence):
            return .flagged(reasons: reasons, confidence: confidence)
        case .blocked(let reasons, let confidence):
            return .blocked(reasons: reasons, confidence: confidence)
        case .requiresReview(let reasons, let confidence):
            return .requiresReview(reasons: reasons, confidence: confidence)
        }
    }
    
    private func updateCanCreateEvent() {
        canCreateEvent = isStateValid(titleState) && 
                        isStateValid(descriptionState) && 
                        isStateValid(hashtagsState) &&
                        (imageState == nil || isStateValid(imageState!))
    }
    
    private func isStateValid(_ state: ValidationState) -> Bool {
        switch state {
        case .valid:
            return true
        case .flagged(_, let confidence):
            return confidence < 0.7 // Allow low-confidence flags
        default:
            return false
        }
    }
    
    func createEvent() async {
        logger.info("Creating event with validated content")
        // Implementation for event creation
    }
}

// MARK: Moderation Status Row

struct ModerationStatusRow: View {
    let title: String
    let state: ValidationState
    
    var body: some View {
        HStack {
            Text(title)
                .font(.caption)
                .foregroundColor(.gray)
            
            Spacer()
            
            Image(systemName: iconName)
                .foregroundColor(iconColor)
                .font(.caption)
            
            Text(statusText)
                .font(.caption)
                .foregroundColor(iconColor)
        }
    }
    
    private var iconName: String {
        switch state {
        case .idle:
            return "circle"
        case .validating:
            return "clock"
        case .valid:
            return "checkmark.circle.fill"
        case .flagged:
            return "exclamationmark.triangle.fill"
        case .blocked:
            return "xmark.circle.fill"
        case .requiresReview:
            return "eye.fill"
        case .error:
            return "exclamationmark.circle.fill"
        }
    }
    
    private var iconColor: Color {
        switch state {
        case .idle:
            return .gray
        case .validating:
            return .blue
        case .valid:
            return .green
        case .flagged:
            return .orange
        case .blocked, .error:
            return .red
        case .requiresReview:
            return .purple
        }
    }
    
    private var statusText: String {
        switch state {
        case .idle:
            return "Ready"
        case .validating:
            return "Checking..."
        case .valid:
            return "Valid"
        case .flagged:
            return "Flagged"
        case .blocked:
            return "Blocked"
        case .requiresReview:
            return "Review"
        case .error:
            return "Error"
        }
    }
}

// MARK: Example 4: Batch Content Moderation

final class BatchModerationManager: ObservableObject {
    @Published var progress: Double = 0.0
    @Published var results: [BatchModerationItem] = []
    @Published var isProcessing = false
    
    private let moderationService = EnhancedContentModerationService.shared
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "Vibesy", 
                               category: "BatchModeration")
    
    struct BatchModerationItem: Identifiable {
        let id = UUID()
        let content: ContentType
        let result: ModerationResult?
        let processingTime: TimeInterval?
        let error: Error?
    }
    
    func processBatch(_ contents: [ContentType]) async {
        await MainActor.run {
            isProcessing = true
            progress = 0.0
            results = contents.map { BatchModerationItem(content: $0, result: nil, processingTime: nil, error: nil) }
        }
        
        let totalItems = contents.count
        var processedItems = 0
        
        // Process in chunks to avoid overwhelming the system
        let chunkSize = 5
        for chunk in contents.chunked(into: chunkSize) {
            await withTaskGroup(of: (ContentType, ModerationResult?, TimeInterval?, Error?).self) { group in
                for content in chunk {
                    group.addTask { [weak self] in
                        let startTime = CFAbsoluteTimeGetCurrent()
                        
                        do {
                            let result = try await self?.moderationService.moderateContent(content)
                            let processingTime = CFAbsoluteTimeGetCurrent() - startTime
                            return (content, result, processingTime, nil)
                        } catch {
                            let processingTime = CFAbsoluteTimeGetCurrent() - startTime
                            return (content, nil, processingTime, error)
                        }
                    }
                }
                
                for await (content, result, processingTime, error) in group {
                    processedItems += 1
                    
                    await MainActor.run {
                        if let index = results.firstIndex(where: { 
                            // Compare content (simplified)
                            return true // In real implementation, compare actual content
                        }) {
                            results[index] = BatchModerationItem(
                                content: content, 
                                result: result, 
                                processingTime: processingTime, 
                                error: error
                            )
                        }
                        
                        progress = Double(processedItems) / Double(totalItems)
                    }
                }
            }
        }
        
        await MainActor.run {
            isProcessing = false
            logger.info("Batch moderation completed: \(results.count) items processed")
        }
    }
}

// MARK: Helper Extensions

extension Array {
    func chunked(into size: Int) -> [[Element]] {
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}

// MARK: Mock Types (for compilation)

struct ImagePickerView: UIViewControllerRepresentable {
    @Binding var selectedImage: UIImage?
    let onImageSelected: (UIImage) -> Void
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ImagePickerView
        
        init(_ parent: ImagePickerView) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.selectedImage = image
                parent.onImageSelected(image)
            }
            picker.dismiss(animated: true)
        }
    }
}
