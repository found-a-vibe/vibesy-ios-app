//
//  HostOnboardingView.swift
//  Vibesy
//
//  Created by Alexander Cleoni on Payment Integration.
//

import SwiftUI
import AuthenticationServices

struct HostOnboardingView: View {
    @StateObject private var viewModel = HostOnboardingViewModel()
    @SwiftUI.Environment(\.dismiss) private var dismiss
    
    let userEmail: String
    let firstName: String?
    let lastName: String?
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 16) {
                        Image(systemName: "creditcard.circle.fill")
                            .font(.system(size: 64))
                            .foregroundColor(.blue)
                        
                        Text("Start Hosting Events")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .multilineTextAlignment(.center)
                        
                        Text("Set up payments to receive money from ticket sales directly to your bank account.")
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    
                    // Benefits
                    VStack(alignment: .leading, spacing: 16) {
                        BenefitRow(icon: "lock.shield", 
                                  title: "Secure & Trusted", 
                                  description: "Powered by Stripe for secure payments")
                        
                        BenefitRow(icon: "banknote", 
                                  title: "Direct Deposits", 
                                  description: "Money deposited directly to your bank account")
                        
                        BenefitRow(icon: "chart.line.uptrend.xyaxis", 
                                  title: "Track Sales", 
                                  description: "Real-time analytics and reporting")
                        
                        BenefitRow(icon: "person.2", 
                                  title: "Global Reach", 
                                  description: "Accept payments from customers worldwide")
                    }
                    .padding(.horizontal)
                    
                    Spacer(minLength: 32)
                    
                    // Action Buttons
                    VStack(spacing: 16) {
                        if viewModel.isLoading {
                            ProgressView("Setting up your account...")
                                .frame(maxWidth: .infinity, minHeight: 50)
                        } else if viewModel.onboardingComplete {
                            VStack(spacing: 12) {
                                HStack {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.green)
                                    Text("Account Setup Complete!")
                                        .fontWeight(.medium)
                                        .foregroundColor(.green)
                                }
                                
                                Button("Continue") {
                                    dismiss()
                                }
                                .buttonStyle(PrimaryButtonStyle())
                            }
                        } else {
                            Button("Set Up Payments") {
                                Task {
                                    await viewModel.startOnboarding(
                                        email: userEmail,
                                        firstName: firstName,
                                        lastName: lastName
                                    )
                                }
                            }
                            .buttonStyle(PrimaryButtonStyle())
                            .disabled(viewModel.isLoading)
                        }
                        
                        Button("Maybe Later") {
                            dismiss()
                        }
                        .foregroundColor(.secondary)
                        .padding()
                    }
                    .padding(.horizontal)
                }
                .padding(.top)
            }
            .navigationTitle("Become a Host")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
            .alert("Setup Error", isPresented: .constant(viewModel.errorMessage != nil)) {
                Button("OK") {
                    viewModel.errorMessage = nil
                }
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
            .onOpenURL { url in
                viewModel.handleReturnURL(url)
            }
        }
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity, minHeight: 50)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.blue)
                    .opacity(configuration.isPressed ? 0.8 : 1.0)
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
    }
}

// MARK: - ViewModel

@MainActor
class HostOnboardingViewModel: ObservableObject {
    @Published var isLoading = false
    @Published var onboardingComplete = false
    @Published var errorMessage: String?
    
    private var webAuthSession: ASWebAuthenticationSession?
    private let apiService = StripeAPIService.shared
    
    func startOnboarding(email: String, firstName: String?, lastName: String?) async {
        isLoading = true
        errorMessage = nil
        
        do {
            let response = try await apiService.createConnectOnboardingLink(
                email: email,
                firstName: firstName,
                lastName: lastName
            )
            
            if response.onboardingComplete {
                self.onboardingComplete = true
                self.isLoading = false
                return
            }
            
            guard let onboardingURL = response.url,
                  let url = URL(string: onboardingURL) else {
                throw APIError.serverError("Invalid onboarding URL")
            }
            
            // Launch web authentication session
            await launchWebAuthSession(url: url)
            
        } catch {
            self.errorMessage = error.localizedDescription
            self.isLoading = false
        }
    }
    
    private func launchWebAuthSession(url: URL) async {
        return await withCheckedContinuation { continuation in
            webAuthSession = ASWebAuthenticationSession(
                url: url,
                callbackURLScheme: "vibesy"
            ) { [weak self] callbackURL, error in
                DispatchQueue.main.async {
                    self?.isLoading = false
                    
                    if let error = error {
                        if let authError = error as? ASWebAuthenticationSessionError,
                           authError.code == .canceledLogin {
                            // User cancelled - this is expected behavior
                        } else {
                            self?.errorMessage = error.localizedDescription
                        }
                    } else if let callbackURL = callbackURL {
                        self?.handleReturnURL(callbackURL)
                    }
                    
                    continuation.resume()
                }
            }
            
            webAuthSession?.presentationContextProvider = WebAuthSessionContextProvider()
            webAuthSession?.prefersEphemeralWebBrowserSession = false
            webAuthSession?.start()
        }
    }
    
    func handleReturnURL(_ url: URL) {
        guard url.scheme == "vibesy",
              url.host == "stripe",
              url.path == "/onboard_complete" else {
            return
        }
        
        // Parse URL parameters to check onboarding status
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        let queryItems = components?.queryItems
        
        // You might want to verify completion with your backend here
        onboardingComplete = true
        isLoading = false
    }
}

// MARK: - Web Authentication Session Context Provider

class WebAuthSessionContextProvider: NSObject, ASWebAuthenticationPresentationContextProviding {
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        return UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow } ?? ASPresentationAnchor()
    }
}

// MARK: - Preview

#Preview {
    HostOnboardingView(
        userEmail: "host@example.com",
        firstName: "John",
        lastName: "Doe"
    )
}
