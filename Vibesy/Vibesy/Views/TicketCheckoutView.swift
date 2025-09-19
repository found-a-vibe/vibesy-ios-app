//
//  TicketCheckoutView.swift
//  Vibesy
//
//  Created by Alexander Cleoni on Payment Integration.
//

import SwiftUI

// NOTE: To use PaymentSheet, you need to add Stripe SDK via Swift Package Manager
// Add this to your project: https://github.com/stripe/stripe-ios

// Uncomment these imports once you add the Stripe SDK:
// import StripePaymentSheet
// import StripeCore

struct TicketCheckoutView: View {
    @StateObject private var viewModel = TicketCheckoutViewModel()
    @SwiftUI.Environment(\.dismiss) private var dismiss
    
    let eventId: Int
    let eventTitle: String
    let venue: String
    let startsAt: String
    let priceCents: Int
    let buyerEmail: String
    let buyerName: String?
    
    @State private var quantity: Int = 1
    
    var totalAmount: Int {
        priceCents * quantity
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Event Details
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            VStack(alignment: .leading, spacing: 8) {
                                Text(eventTitle)
                                    .font(.title2)
                                    .fontWeight(.bold)
                                
                                HStack {
                                    Image(systemName: "location")
                                        .foregroundColor(.secondary)
                                    Text(venue)
                                        .foregroundColor(.secondary)
                                }
                                
                                HStack {
                                    Image(systemName: "calendar")
                                        .foregroundColor(.secondary)
                                    Text(formatEventDate(startsAt))
                                        .foregroundColor(.secondary)
                                }
                            }
                            
                            Spacer()
                        }
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(.systemGray6))
                    )
                    
                    // Ticket Selection
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Select Tickets")
                            .font(.headline)
                        
                        HStack {
                            Text("Number of tickets:")
                            
                            Spacer()
                            
                            HStack(spacing: 12) {
                                Button {
                                    if quantity > 1 {
                                        quantity -= 1
                                    }
                                } label: {
                                    Image(systemName: "minus")
                                        .font(.title2)
                                        .foregroundColor(quantity > 1 ? .blue : .gray)
                                }
                                .disabled(quantity <= 1)
                                
                                Text("\(quantity)")
                                    .font(.title2)
                                    .fontWeight(.semibold)
                                    .frame(minWidth: 40)
                                
                                Button {
                                    if quantity < 10 {
                                        quantity += 1
                                    }
                                } label: {
                                    Image(systemName: "plus")
                                        .font(.title2)
                                        .foregroundColor(quantity < 10 ? .blue : .gray)
                                }
                                .disabled(quantity >= 10)
                            }
                        }
                        
                        Divider()
                        
                        HStack {
                            Text("Price per ticket:")
                            Spacer()
                            Text(formatCurrency(priceCents))
                                .fontWeight(.semibold)
                        }
                        
                        HStack {
                            Text("Total:")
                                .font(.headline)
                            Spacer()
                            Text(formatCurrency(totalAmount))
                                .font(.headline)
                                .fontWeight(.bold)
                        }
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(.systemGray6))
                    )
                    
                    // Payment Methods Info
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Payment Methods")
                            .font(.headline)
                        
                        HStack {
                            Image(systemName: "apple.logo")
                            Text("Apple Pay")
                            Spacer()
                            Image(systemName: "checkmark")
                                .foregroundColor(.green)
                        }
                        
                        HStack {
                            Image(systemName: "creditcard")
                            Text("Credit & Debit Cards")
                            Spacer()
                            Image(systemName: "checkmark")
                                .foregroundColor(.green)
                        }
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(.systemGray6))
                    )
                    
                    Spacer(minLength: 32)
                    
                    // Purchase Button
                    VStack(spacing: 16) {
                        if viewModel.isProcessing {
                            ProgressView("Processing payment...")
                                .frame(maxWidth: .infinity, minHeight: 50)
                        } else if viewModel.purchaseCompleted {
                            VStack(spacing: 12) {
                                HStack {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.green)
                                    Text("Purchase Successful!")
                                        .fontWeight(.medium)
                                        .foregroundColor(.green)
                                }
                                
                                Button("View Tickets") {
                                    viewModel.showTickets = true
                                }
                                .buttonStyle(PrimaryButtonStyle())
                            }
                        } else {
                            Button("Purchase Tickets - \(formatCurrency(totalAmount))") {
                                Task {
                                    await viewModel.purchaseTickets(
                                        eventId: eventId,
                                        quantity: quantity,
                                        buyerEmail: buyerEmail,
                                        buyerName: buyerName
                                    )
                                }
                            }
                            .buttonStyle(PrimaryButtonStyle())
                            .disabled(viewModel.isProcessing)
                        }
                        
                        if !viewModel.purchaseCompleted {
                            Button("Cancel") {
                                dismiss()
                            }
                            .foregroundColor(.secondary)
                            .padding()
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Checkout")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if !viewModel.purchaseCompleted {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("Cancel") {
                            dismiss()
                        }
                    }
                }
            }
            .alert("Payment Error", isPresented: .constant(viewModel.errorMessage != nil)) {
                Button("OK") {
                    viewModel.errorMessage = nil
                }
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
            .sheet(isPresented: $viewModel.showTickets) {
                if let orderId = viewModel.completedOrderId {
                    TicketListView(orderId: orderId)
                }
            }
            // Uncomment this once you add Stripe SDK:
            /*
            .paymentSheet(isPresented: $viewModel.showPaymentSheet,
                         paymentSheet: viewModel.paymentSheet) { result in
                viewModel.handlePaymentResult(result)
            }
            */
        }
    }
    
    private func formatCurrency(_ cents: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        return formatter.string(from: NSNumber(value: Double(cents) / 100.0)) ?? "$0.00"
    }
    
    private func formatEventDate(_ dateString: String) -> String {
        let formatter = ISO8601DateFormatter()
        guard let date = formatter.date(from: dateString) else {
            return dateString
        }
        
        let displayFormatter = DateFormatter()
        displayFormatter.dateStyle = .medium
        displayFormatter.timeStyle = .short
        return displayFormatter.string(from: date)
    }
}

// MARK: - ViewModel

@MainActor
class TicketCheckoutViewModel: ObservableObject {
    @Published var isProcessing = false
    @Published var purchaseCompleted = false
    @Published var errorMessage: String?
    @Published var showPaymentSheet = false
    @Published var showTickets = false
    @Published var completedOrderId: Int?
    
    private let apiService = StripeAPIService.shared
    
    // Uncomment these once you add Stripe SDK:
    // @Published var paymentSheet: PaymentSheet?
    // private var paymentIntentClientSecret: String?
    
    func purchaseTickets(eventId: Int, quantity: Int, buyerEmail: String, buyerName: String?) async {
        isProcessing = true
        errorMessage = nil
        
        do {
            let response = try await apiService.createPaymentIntent(
                eventId: eventId,
                quantity: quantity,
                buyerEmail: buyerEmail,
                buyerName: buyerName
            )
            
            completedOrderId = response.orderId
            
            // Uncomment this section once you add Stripe SDK:
            /*
            // Configure PaymentSheet
            var configuration = PaymentSheet.Configuration()
            configuration.merchantDisplayName = "Vibesy"
            
            // Configure Apple Pay
            configuration.applePay = .init(
                merchantId: StripeConfig.merchantId,
                merchantCountryCode: StripeConfig.merchantCountryCode
            )
            
            // Set customer configuration
            configuration.customer = .init(
                id: response.customer,
                ephemeralKeySecret: response.ephemeralKey
            )
            
            // Set return URL for redirects
            configuration.returnURL = "vibesy://payment_complete"
            
            // Create PaymentSheet
            paymentSheet = PaymentSheet(
                paymentIntentClientSecret: response.paymentIntentClientSecret,
                configuration: configuration
            )
            
            paymentIntentClientSecret = response.paymentIntentClientSecret
            
            // Show payment sheet
            showPaymentSheet = true
            */
            
            // For demo purposes without Stripe SDK:
            // Simulate successful payment after 2 seconds
            try await Task.sleep(nanoseconds: 2_000_000_000)
            purchaseCompleted = true
            
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isProcessing = false
    }
    
    // Uncomment this once you add Stripe SDK:
    /*
    func handlePaymentResult(_ result: PaymentSheetResult) {
        switch result {
        case .completed:
            purchaseCompleted = true
            
        case .canceled:
            // Payment was cancelled by user
            break
            
        case .failed(let error):
            errorMessage = error.localizedDescription
        }
        
        isProcessing = false
    }
    */
}

// MARK: - Preview

#Preview {
    TicketCheckoutView(
        eventId: 1,
        eventTitle: "Summer Music Festival 2024",
        venue: "Central Park",
        startsAt: "2024-07-15T19:00:00Z",
        priceCents: 2500,
        buyerEmail: "buyer@example.com",
        buyerName: "John Doe"
    )
}
