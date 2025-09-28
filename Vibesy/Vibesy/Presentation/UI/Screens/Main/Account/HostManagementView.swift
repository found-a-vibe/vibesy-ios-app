//
//  HostManagementView.swift
//  Vibesy
//
//  Created by Alexander Cleoni on Stripe Integration.
//

import SwiftUI
import AuthenticationServices

struct HostManagementView: View {
    @EnvironmentObject var authenticationModel: AuthenticationModel
    @StateObject private var stripeStatusManager = StripeStatusManager.shared
    @State private var showOnboardingSheet = false
    @State private var showDisconnectAlert = false
    @State private var showErrorAlert = false
    @State private var errorMessage = ""
    
    var navigate: ((_ direction: Direction) -> Void)? = nil
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                BackButtonView {
                    if let navigate {
                        navigate(.back)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                Text("Host Settings")
                    .font(.abeezeeItalic(size: 24))
                    .foregroundStyle(.espresso)
                    .frame(maxWidth: .infinity, alignment: .center)
                
                Spacer()
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .padding()
            
            ScrollView {
                VStack(spacing: 24) {
                    // Stripe Connect Status Card
                    stripeStatusCard()
                    
                    // Host Benefits Card
                    hostBenefitsCard()
                    
                    // Action Buttons
                    actionButtonsSection()
                }
                .padding()
            }
        }
        .onAppear {
            refreshStripeStatus()
        }
        .alert("Disconnect Stripe Account", isPresented: $showDisconnectAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Disconnect", role: .destructive) {
                Task {
                    await disconnectStripeAccount()
                }
            }
        } message: {
            Text("Are you sure you want to disconnect your Stripe account? You won't be able to charge for events until you reconnect.")
        }
        .alert("Error", isPresented: $showErrorAlert) {
            Button("OK") {}
        } message: {
            Text(errorMessage)
        }
        .sheet(isPresented: $showOnboardingSheet) {
            if let user = authenticationModel.state.currentUser {
                HostOnboardingView(
                    userEmail: user.email,
                    firstName: nil, // AuthUser doesn't have firstName
                    lastName: nil,  // AuthUser doesn't have lastName
                    onCompletion: {
                        // Refresh the Stripe status when onboarding completes
                        refreshStripeStatus(forceRefresh: true)
                    }
                )
            }
        }
    }
    
    @ViewBuilder
    private func stripeStatusCard() -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "creditcard.circle.fill")
                    .font(.title2)
                    .foregroundColor(.blue)
                
                Text("Payment Setup")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                if stripeStatusManager.isLoading {
                    ProgressView()
                        .scaleEffect(0.8)
                }
            }
            
            if stripeStatusManager.hasConnectAccount {
                if stripeStatusManager.onboardingComplete {
                    // Onboarding Complete
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Connected & Ready")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.green)
                            Text("You can charge for events and receive payments")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                    }
                    
                    if let accountId = stripeStatusManager.stripeAccountId {
                        Text("Account ID: \(String(accountId.prefix(12)))...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.leading, 24)
                    }
                } else {
                    // Connected but not complete
                    HStack {
                        Image(systemName: "exclamationmark.circle.fill")
                            .foregroundColor(.orange)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Setup Incomplete")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.orange)
                            Text("Complete your onboarding to start charging for events")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                    }
                }
            } else {
                // Not connected
                HStack {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.red)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Not Connected")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.red)
                        Text("Connect your Stripe account to charge for events")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
    
    @ViewBuilder
    private func hostBenefitsCard() -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Host Benefits")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(alignment: .leading, spacing: 12) {
                BenefitRow(
                    icon: "banknote.fill",
                    title: "Direct Deposits",
                    description: "Get paid directly to your bank account"
                )
                
                BenefitRow(
                    icon: "chart.line.uptrend.xyaxis",
                    title: "Real-time Analytics",
                    description: "Track sales and earnings in real-time"
                )
                
                BenefitRow(
                    icon: "shield.checkerboard",
                    title: "Secure Payments",
                    description: "PCI-compliant payment processing by Stripe"
                )
                
                BenefitRow(
                    icon: "globe",
                    title: "Global Reach",
                    description: "Accept payments from customers worldwide"
                )
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
    
    @ViewBuilder
    private func actionButtonsSection() -> some View {
        VStack(spacing: 16) {
            if !stripeStatusManager.hasConnectAccount {
                // Connect Button
                Button("Connect Stripe Account") {
                    showOnboardingSheet = true
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(stripeStatusManager.isLoading)
                
            } else if !stripeStatusManager.onboardingComplete {
                // Complete Onboarding Button
                Button("Complete Setup") {
                    showOnboardingSheet = true
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(stripeStatusManager.isLoading)
                
            } else {
                // Refresh Status Button
                Button("Refresh Status") {
                    refreshStripeStatus(forceRefresh: true)
                }
                .buttonStyle(SecondaryButtonStyle())
                .disabled(stripeStatusManager.isLoading)
            }
            
            // Disconnect Button (only if connected)
            if stripeStatusManager.hasConnectAccount {
                Button("Disconnect Account") {
                    showDisconnectAlert = true
                }
                .buttonStyle(DangerButtonStyle())
                .disabled(stripeStatusManager.isLoading)
            }
        }
    }
    
    // MARK: - Helper Functions
    
    private func refreshStripeStatus(forceRefresh: Bool = false) {
        guard let userEmail = authenticationModel.state.currentUser?.email else { return }
        
        Task {
            await stripeStatusManager.syncStripeStatus(email: userEmail, forceRefresh: forceRefresh)
            
            if let error = stripeStatusManager.errorMessage {
                errorMessage = error
                showErrorAlert = true
            }
        }
    }
    
    private func disconnectStripeAccount() async {
        guard let userEmail = authenticationModel.state.currentUser?.email else { return }
        
        do {
            try await stripeStatusManager.disconnectStripe(email: userEmail)
        } catch {
            errorMessage = error.localizedDescription
            showErrorAlert = true
        }
    }
}

// MARK: - Benefit Row Component

struct BenefitRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(.blue)
                .frame(width: 24, height: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
    }
}

// MARK: - Button Styles

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundColor(.blue)
            .frame(maxWidth: .infinity, minHeight: 50)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.blue, lineWidth: 2)
                    .opacity(configuration.isPressed ? 0.8 : 1.0)
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
    }
}

struct DangerButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity, minHeight: 50)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.red)
                    .opacity(configuration.isPressed ? 0.8 : 1.0)
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
    }
}

#Preview {
    HostManagementView()
}