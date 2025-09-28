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
    let onCompletion: (() -> Void)?
    
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
                                    onCompletion?()
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
            .onAppear {
                // Set the completion callback
                if let onCompletion = onCompletion {
                    viewModel.setCompletionCallback(onCompletion)
                }
                
                Task {
                    await viewModel.checkInitialOnboardingStatus(email: userEmail)
                }
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
    private var contextProvider: WebAuthSessionContextProvider?
    private var currentUserEmail: String?
    private var completionCallback: (() -> Void)?
    private let apiService = StripeAPIService.shared
    
    func startOnboarding(email: String, firstName: String?, lastName: String?) async {
        print("🚀 Starting onboarding for: \(email)")
        currentUserEmail = email
        isLoading = true
        errorMessage = nil
        
        do {
            print("📞 Making API call to create onboarding link...")
            let response = try await apiService.createConnectOnboardingLink(
                email: email,
                firstName: firstName,
                lastName: lastName
            )
            
            print("✅ API response received. Onboarding complete: \(response.onboardingComplete)")
            
            if response.onboardingComplete {
                print("✅ Onboarding already complete!")
                self.onboardingComplete = true
                self.isLoading = false
                return
            }
            
            guard let onboardingURL = response.url,
                  let url = URL(string: onboardingURL) else {
                print("❌ Invalid or missing onboarding URL: \(response.url ?? "nil")")
                throw APIError.serverError("Invalid onboarding URL")
            }
            
            print("🔗 Got onboarding URL: \(url.absoluteString)")
            
            // Launch web authentication session
            await launchWebAuthSession(url: url)
            
        } catch {
            print("❌ Onboarding error: \(error.localizedDescription)")
            self.errorMessage = error.localizedDescription
            self.isLoading = false
        }
    }
    
    private func launchWebAuthSession(url: URL) async {
        return await withCheckedContinuation { continuation in
            // Ensure continuation is resumed exactly once
            var didResume = false
            func resumeIfNeeded() {
                guard !didResume else { return }
                didResume = true
                continuation.resume()
            }

            // Make sure we're on the main thread for UI operations
            DispatchQueue.main.async {
                // Create the session and keep a strong reference via the property
                let session = ASWebAuthenticationSession(
                    url: url,
                    callbackURLScheme: "vibesy"
                ) { [weak self] callbackURL, error in
                    // Ensure self stays alive during this callback by promoting to strong
                    guard let strongSelf = self else {
                        resumeIfNeeded()
                        return
                    }

                    DispatchQueue.main.async {
                        strongSelf.isLoading = false

                        if let error = error {
                            if let authError = error as? ASWebAuthenticationSessionError,
                               authError.code == .canceledLogin {
                                // User cancelled - expected behavior; no error shown
                                print("👤 User cancelled Stripe onboarding")
                            } else {
                                print("❌ Authentication session error: \(error.localizedDescription)")
                                strongSelf.errorMessage = error.localizedDescription
                            }
                        } else if let callbackURL = callbackURL {
                            print("✅ Received callback URL: \(callbackURL.absoluteString)")
                            strongSelf.handleReturnURL(callbackURL)
                        }

                        // Break potential retain cycle and finish continuation
                        strongSelf.webAuthSession = nil
                        strongSelf.contextProvider = nil
                        resumeIfNeeded()
                    }
                }

                // Assign to property to keep it alive for the duration of auth
                self.webAuthSession = session
                
                // Set up the presentation context provider and keep it alive
                self.contextProvider = WebAuthSessionContextProvider()
                self.webAuthSession?.presentationContextProvider = self.contextProvider
                
                // Use ephemeral session to avoid login conflicts
                self.webAuthSession?.prefersEphemeralWebBrowserSession = false
                
                print("🚀 Starting authentication session for URL: \(url.absoluteString)")
                let started = self.webAuthSession?.start() ?? false
                print("📊 Authentication session started: \(started)")

                // If start failed synchronously, clean up and resume
                if !started {
                    print("❌ Failed to start authentication session synchronously")
                    self.isLoading = false
                    self.errorMessage = "Failed to start authentication session. Please try again."
                    self.webAuthSession = nil
                    self.contextProvider = nil
                    resumeIfNeeded()
                }
            }
        }
    }
    
    func handleReturnURL(_ url: URL) {
        guard url.scheme == "vibesy",
              url.host == "stripe",
              url.path == "/onboard_complete" else {
            print("⚠️ Received unexpected return URL: \(url.absoluteString)")
            return
        }
        
        print("✅ Handling Stripe onboard completion callback")
        
        // Parse URL parameters
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        let accountId = components?.queryItems?.first(where: { $0.name == "account_id" })?.value
        
        // Verify completion with backend
        Task {
            await verifyOnboardingCompletion(accountId: accountId)
        }
    }
    
    func setCompletionCallback(_ callback: @escaping () -> Void) {
        self.completionCallback = callback
    }
    
    func checkInitialOnboardingStatus(email: String) async {
        currentUserEmail = email
        
        do {
            let response = try await apiService.getConnectStatus(email: email)
            
            DispatchQueue.main.async {
                self.onboardingComplete = response.onboardingComplete
                print("🔄 Initial onboarding status for \(email): \(response.onboardingComplete)")
                
                // If already complete on initial check, call completion callback
                if response.onboardingComplete {
                    self.completionCallback?()
                }
            }
        } catch {
            print("⚠️ Failed to check initial onboarding status: \(error.localizedDescription)")
            // Don't show error for initial status check, just assume not complete
        }
    }
    
    private func verifyOnboardingCompletion(accountId: String?) async {
        guard let email = currentUserEmail else {
            print("❌ No user email stored for verification")
            errorMessage = "Unable to verify onboarding completion"
            return
        }
        
        print("🔍 Verifying onboarding completion with backend...")
        isLoading = true
        
        do {
            let response = try await apiService.verifyOnboardingComplete(
                email: email,
                accountId: accountId
            )
            
            print("✅ Verification response: onboarding complete = \(response.onboardingComplete)")
            
            DispatchQueue.main.async {
                self.onboardingComplete = response.onboardingComplete
                self.isLoading = false
                
                if response.onboardingComplete {
                    // Call completion callback when successfully verified
                    self.completionCallback?()
                } else {
                    self.errorMessage = "Onboarding setup is still incomplete. Please try the setup process again."
                }
            }
            
        } catch {
            print("❌ Failed to verify onboarding completion: \(error.localizedDescription)")
            
            DispatchQueue.main.async {
                self.isLoading = false
                self.errorMessage = "Unable to verify setup completion: \(error.localizedDescription)"
            }
        }
    }
}

// MARK: - Web Authentication Session Context Provider

class WebAuthSessionContextProvider: NSObject, ASWebAuthenticationPresentationContextProviding {
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        // Try to get the key window from connected scenes
        if let windowScene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive }),
           let keyWindow = windowScene.windows.first(where: { $0.isKeyWindow }) {
            return keyWindow
        }
        
        // Fallback: get any key window
        if let keyWindow = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .flatMap({ $0.windows })
            .first(where: { $0.isKeyWindow }) {
            return keyWindow
        }
        
        // Final fallback: create a new window if needed
        print("⚠️ No key window found for web authentication session")
        return UIWindow()
    }
}

// MARK: - Preview

#Preview {
    HostOnboardingView(
        userEmail: "host@example.com",
        firstName: "John",
        lastName: "Doe",
        onCompletion: nil
    )
}
