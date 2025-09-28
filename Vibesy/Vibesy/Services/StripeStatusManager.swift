//
//  StripeStatusManager.swift
//  Vibesy
//
//  Created by Alexander Cleoni on Stripe Integration.
//

import Foundation
import Combine

@MainActor
class StripeStatusManager: ObservableObject {
    static let shared = StripeStatusManager()
    
    @Published var isHost: Bool = false
    @Published var hasConnectAccount: Bool = false
    @Published var onboardingComplete: Bool = false
    @Published var stripeAccountId: String?
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    
    private let apiService = StripeAPIService.shared
    private var lastUpdateTime: Date?
    private let cacheValidityDuration: TimeInterval = 300 // 5 minutes
    
    private init() {}
    
    /// Check if cached data is still valid
    private var isCacheValid: Bool {
        guard let lastUpdate = lastUpdateTime else { return false }
        return Date().timeIntervalSince(lastUpdate) < cacheValidityDuration
    }
    
    /// Sync Stripe status from backend
    func syncStripeStatus(email: String, forceRefresh: Bool = false) async {
        // Return cached data if valid and not forcing refresh
        if isCacheValid && !forceRefresh {
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        do {
            let response = try await apiService.getConnectStatus(email: email)
            
            // Update local state
            hasConnectAccount = response.hasConnectAccount
            onboardingComplete = response.onboardingComplete
            stripeAccountId = response.accountId
            isHost = response.role == "host"
            
            // Update cache timestamp
            lastUpdateTime = Date()
            
        } catch {
            errorMessage = error.localizedDescription
            // On error, don't assume any capabilities
            hasConnectAccount = false
            onboardingComplete = false
            stripeAccountId = nil
        }
        
        isLoading = false
    }
    
    /// Update UserProfile with current Stripe status
    func updateUserProfile(_ userProfile: inout UserProfile) {
        userProfile.updateStripeInfo(
            connectId: stripeAccountId,
            onboardingComplete: onboardingComplete,
            isHost: isHost
        )
    }
    
    /// Check if user can create paid events
    var canCreatePaidEvents: Bool {
        return hasConnectAccount && onboardingComplete
    }
    
    /// Start onboarding process
    func startOnboarding(email: String, firstName: String?, lastName: String?) async throws -> String? {
        isLoading = true
        errorMessage = nil
        
        defer {
            isLoading = false
        }
        
        do {
            let response = try await apiService.createConnectOnboardingLink(
                email: email,
                firstName: firstName,
                lastName: lastName
            )
            
            // Update local state with response
            hasConnectAccount = true
            stripeAccountId = response.accountId
            onboardingComplete = response.onboardingComplete
            isHost = true
            
            // Update cache timestamp
            lastUpdateTime = Date()
            
            return response.url
            
        } catch {
            errorMessage = error.localizedDescription
            throw error
        }
    }
    
    /// Disconnect Stripe account
    func disconnectStripe(email: String) async throws {
        isLoading = true
        errorMessage = nil
        
        defer {
            isLoading = false
        }
        
        do {
            try await apiService.disconnectStripe(email: email)
            
            // Clear local state
            hasConnectAccount = false
            onboardingComplete = false
            stripeAccountId = nil
            isHost = false
            
            // Update cache timestamp
            lastUpdateTime = Date()
            
        } catch {
            errorMessage = error.localizedDescription
            throw error
        }
    }
    
    /// Reset cache (useful when user logs out)
    func resetCache() {
        hasConnectAccount = false
        onboardingComplete = false
        stripeAccountId = nil
        isHost = false
        lastUpdateTime = nil
        errorMessage = nil
    }
}
