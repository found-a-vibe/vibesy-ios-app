//
//  HostManagementView.swift
//  Vibesy
//
//  Created by Alexander Cleoni on Stripe Integration.
//

import AuthenticationServices
import SwiftUI

struct HostManagementView: View {
    @EnvironmentObject var authenticationModel: AuthenticationModel
    @StateObject private var stripeStatusManager = StripeStatusManager.shared
    @State private var showOnboardingSheet = false
    @State private var showDisconnectAlert = false
    @State private var showErrorAlert = false
    @State private var errorMessage = ""
    @State private var showDashboardSheet = false
    @State private var dashboardURL: IdentifiedURL?

    var navigate: ((_ direction: Direction) -> Void)? = nil

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                BackButtonView(color: .goldenBrown) {
                    if let navigate {
                        navigate(.back)
                    }
                }

                Spacer()
                Text("Host Settings")
                    .font(.aBeeZeeRegular(size: 24))
                    .foregroundStyle(.goldenBrown)
                Spacer()
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
            .refreshable {
                refreshStripeStatus(forceRefresh: true)
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
            Text(
                "Are you sure you want to disconnect your Stripe account? You won't be able to charge for events until you reconnect."
            )
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
                    firstName: nil,  // AuthUser doesn't have firstName
                    lastName: nil,  // AuthUser doesn't have lastName
                    onCompletion: {
                        // Refresh the Stripe status when onboarding completes
                        refreshStripeStatus(forceRefresh: true)
                    }
                )
            }
        }
        .sheet(isPresented: $showDashboardSheet) {
            if let dashboardURL = dashboardURL {
                NavigationView {
                    WebView(url: dashboardURL.url)
                        .navigationTitle("Stripe Dashboard")
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .navigationBarTrailing) {
                                Button("Done") {
                                    showDashboardSheet = false
                                }
                            }
                        }
                }
            }
        }
    }

    @ViewBuilder
    private func stripeStatusCard() -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "creditcard.circle.fill")
                    .font(.title2)
                    .foregroundColor(.espresso)

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
                            .foregroundColor(.goldenBrown)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Connected & Ready")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.goldenBrown)
                            Text(
                                "You can charge for events and receive payments"
                            )
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
                            Text(
                                "Complete your onboarding to start charging for events"
                            )
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
                Button(
                    action: {
                        showOnboardingSheet = true
                    },
                    label: {
                        Text("Connect Stripe Account")
                            .font(.aBeeZeeRegular(size: 20))
                            .frame(maxWidth: .infinity, maxHeight: 51)
                            .foregroundStyle(.white)
                            .tint(.goldenBrown)
                    }
                )
                .frame(height: 51)
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.roundedRectangle(radius: 8))
                .disabled(stripeStatusManager.isLoading)

            } else if !stripeStatusManager.onboardingComplete {
                // Complete Onboarding Button
                Button("Complete Setup") {
                    showOnboardingSheet = true
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(stripeStatusManager.isLoading)

            } else {
                // View Dashboard Button
                Button(
                    action: {
                        openStripeDashboard()
                    },
                    label: {
                        Text("View Stripe Dashboard")
                            .font(.aBeeZeeRegular(size: 20))
                            .frame(maxWidth: .infinity, maxHeight: 51)
                            .foregroundStyle(.white)
                    }
                )
                .frame(height: 51)
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.roundedRectangle(radius: 8))
                .tint(.goldenBrown)
                .disabled(stripeStatusManager.isLoading)
            }

            // Disconnect Button (only if connected)
            if stripeStatusManager.hasConnectAccount {
                Button(
                    action: {
                        showDisconnectAlert = true
                    },
                    label: {
                        Text("Disconnect Account")
                            .font(.aBeeZeeRegular(size: 20))
                            .frame(maxWidth: .infinity, maxHeight: 51)
                            .foregroundStyle(.white)
                    }
                )
                .frame(height: 51)
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.roundedRectangle(radius: 8))
                .tint(.red)
                .disabled(stripeStatusManager.isLoading)
            }
        }
    }

    // MARK: - Helper Functions

    private func refreshStripeStatus(forceRefresh: Bool = false) {
        guard let userEmail = authenticationModel.state.currentUser?.email
        else { return }

        Task {
            await stripeStatusManager.syncStripeStatus(
                email: userEmail,
                forceRefresh: forceRefresh
            )

            if let error = stripeStatusManager.errorMessage {
                errorMessage = error
                showErrorAlert = true
            }
        }
    }

    private func disconnectStripeAccount() async {
        guard let userEmail = authenticationModel.state.currentUser?.email
        else { return }

        do {
            try await stripeStatusManager.disconnectStripe(email: userEmail)
        } catch {
            errorMessage = error.localizedDescription
            showErrorAlert = true
        }
    }

    private func openStripeDashboard() {
        guard let userEmail = authenticationModel.state.currentUser?.email
        else { return }

        Task {
            do {
                if let url = try await stripeStatusManager.getDashboardLink(
                    email: userEmail
                ) {
                    await MainActor.run {
                        dashboardURL = IdentifiedURL(string: url)
                        showDashboardSheet = true
                    }
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    showErrorAlert = true
                }
            }
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
                .foregroundColor(.espresso)
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
