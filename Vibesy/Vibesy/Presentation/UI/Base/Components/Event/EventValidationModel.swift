//
//  EventValidationModel.swift
//  Vibesy
//
//  Created by Alexander Cleoni on Event Validation.
//

import Foundation
import SwiftUI

// MARK: - Field Validation Errors

enum EventFieldError: LocalizedError, Equatable {
    case titleEmpty
    case locationEmpty
    case detailsEmpty
    case noTags
    case noImages
    case invalidPrice
    case invalidTimeRange
    
    var errorDescription: String? {
        switch self {
        case .titleEmpty:
            return "Event title is required"
        case .locationEmpty:
            return "Event location is required"
        case .detailsEmpty:
            return "Event details are required"
        case .noTags:
            return "At least one event tag is required"
        case .noImages:
            return "At least one event image is required"
        case .invalidPrice:
            return "Please enter a valid price amount"
        case .invalidTimeRange:
            return "End time must be after start time"
        }
    }
    
    var fieldName: String {
        switch self {
        case .titleEmpty:
            return "title"
        case .locationEmpty:
            return "location"
        case .detailsEmpty:
            return "details"
        case .noTags:
            return "tags"
        case .noImages:
            return "images"
        case .invalidPrice:
            return "price"
        case .invalidTimeRange:
            return "time"
        }
    }
}

// MARK: - Event Validation Model

@MainActor
class EventValidationModel: ObservableObject {
    @Published var fieldErrors: [String: EventFieldError] = [:]
    @Published var showValidationErrors: Bool = false
    
    // MARK: - Validation Methods
    
    func validateTitle(_ title: String) -> Bool {
        let isValid = !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        updateFieldError(.titleEmpty, for: "title", isValid: isValid)
        return isValid
    }
    
    func validateLocation(_ location: String?) -> Bool {
        let isValid = !(location?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
        updateFieldError(.locationEmpty, for: "location", isValid: isValid)
        return isValid
    }
    
    func validateDetails(_ details: String) -> Bool {
        let isValid = !details.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        updateFieldError(.detailsEmpty, for: "details", isValid: isValid)
        return isValid
    }
    
    func validateTags(_ tags: [String]) -> Bool {
        let isValid = !tags.isEmpty
        updateFieldError(.noTags, for: "tags", isValid: isValid)
        return isValid
    }
    
    func validateImages(_ images: [UIImage]) -> Bool {
        let isValid = !images.isEmpty
        updateFieldError(.noImages, for: "images", isValid: isValid)
        return isValid
    }
    
    func validateTimeRange(start: Date, end: Date) -> Bool {
        let isValid = end > start
        updateFieldError(.invalidTimeRange, for: "time", isValid: isValid)
        return isValid
    }
    
    func validatePrice(_ priceString: String) -> (isValid: Bool, decimal: Decimal?) {
        guard !priceString.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            // Empty price is valid (optional field)
            updateFieldError(.invalidPrice, for: "price", isValid: true)
            return (true, nil)
        }
        
        let normalized = priceString
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "$", with: "")
            .replacingOccurrences(of: ",", with: ".")
        
        if let decimal = Decimal(string: normalized), decimal >= 0 {
            updateFieldError(.invalidPrice, for: "price", isValid: true)
            return (true, decimal)
        } else {
            updateFieldError(.invalidPrice, for: "price", isValid: false)
            return (false, nil)
        }
    }
    
    // MARK: - Form Validation
    
    func validateBasicEventForm(
        title: String,
        location: String?,
        details: String,
        tags: [String],
        startTime: Date,
        endTime: Date
    ) -> Bool {
        let titleValid = validateTitle(title)
        let locationValid = validateLocation(location)
        let detailsValid = validateDetails(details)
        let tagsValid = validateTags(tags)
        let timeValid = validateTimeRange(start: startTime, end: endTime)
        
        showValidationErrors = true
        
        return titleValid && locationValid && detailsValid && tagsValid && timeValid
    }
    
    func validateCompleteEventForm(
        title: String,
        location: String?,
        details: String,
        tags: [String],
        startTime: Date,
        endTime: Date,
        images: [UIImage]
    ) -> Bool {
        let basicValid = validateBasicEventForm(
            title: title,
            location: location,
            details: details,
            tags: tags,
            startTime: startTime,
            endTime: endTime
        )
        let imagesValid = validateImages(images)
        
        return basicValid && imagesValid
    }
    
    // MARK: - Helper Methods
    
    private func updateFieldError(_ error: EventFieldError, for field: String, isValid: Bool) {
        if isValid {
            fieldErrors.removeValue(forKey: field)
        } else {
            fieldErrors[field] = error
        }
    }
    
    func hasError(for field: String) -> Bool {
        return fieldErrors[field] != nil
    }
    
    func errorMessage(for field: String) -> String? {
        return fieldErrors[field]?.errorDescription
    }
    
    func clearValidationErrors() {
        fieldErrors.removeAll()
        showValidationErrors = false
    }
    
    var isFormValid: Bool {
        return fieldErrors.isEmpty
    }
    
    var hasAnyErrors: Bool {
        return !fieldErrors.isEmpty
    }
}

// MARK: - View Extension for Field Styling

extension View {
    func fieldBorder(hasError: Bool, showErrors: Bool = true) -> some View {
        self.overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(
                    hasError && showErrors ? Color.red : Color.gray,
                    lineWidth: hasError && showErrors ? 2 : 1
                )
        )
    }
    
    func fieldErrorMessage(_ message: String?, showErrors: Bool = true) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            self
            if let message = message, showErrors {
                Text(message)
                    .font(.caption)
                    .foregroundColor(.red)
                    .transition(.opacity)
            }
        }
    }
}