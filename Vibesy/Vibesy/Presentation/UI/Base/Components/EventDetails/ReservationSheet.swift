//
//  ReservationSheet.swift
//  Vibesy
//
//  Created by Alexander Cleoni on Reservation Integration.
//

import SwiftUI
import Combine
import StripePaymentSheet

struct ReservationSheet: View {
    @SwiftUI.Environment(\.dismiss) private var dismiss
    @EnvironmentObject var authenticationModel: AuthenticationModel
    @StateObject private var paymentService = PaymentService.shared
    @StateObject private var userOrdersService = UserOrdersService.shared
    private let stripeAPIService = StripeAPIService.shared
    
    let event: Event
    let onReservationSuccess: (() -> Void)?
    
    init(event: Event, onReservationSuccess: (() -> Void)? = nil) {
        self.event = event
        self.onReservationSuccess = onReservationSuccess
    }
    
    @State private var selectedPriceIndex: Int?
    @State private var quantity: Int = 1
    @State private var isProcessingPayment = false
    @State private var showPaymentSuccess = false
    @State private var showPaymentError = false
    @State private var paymentErrorMessage = ""
    
    // Real PaymentSheet properties
    @State private var showPaymentSheet = false
    @State private var paymentSheet: PaymentSheet?
    @State private var paymentIntentId: String?
    
    
    // For free events
    @State private var showReservationConfirmation = false
    
    // For external link events
    @State private var showExternalWebView = false
    
    var selectedPrice: PriceDetails? {
        guard let index = selectedPriceIndex, 
              event.priceDetails.indices.contains(index) else { return nil }
        return event.priceDetails[index]
    }
    
    var totalAmount: Decimal {
        guard let price = selectedPrice else { return 0 }
        return price.price * Decimal(quantity)
    }
    
    var hasFreePricing: Bool {
        event.isFreeEvent || event.priceDetails.allSatisfy { $0.type == .free }
    }
    
    var hasExternalLinks: Bool {
        event.hasExternalTicketLinks
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Event Header
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            VStack(alignment: .leading, spacing: 8) {
                                Text(event.title)
                                    .font(.title2)
                                    .fontWeight(.bold)
                                    .foregroundColor(.espresso)
                                
                                HStack {
                                    Image(systemName: "location")
                                        .foregroundColor(.sandstone)
                                    Text(event.location)
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                                
                                HStack {
                                    Image(systemName: "calendar")
                                        .foregroundColor(.sandstone)
                                    Text("\(event.date) • \(event.timeRange)")
                                        .font(.subheadline)
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
                    
                    if hasExternalLinks {
                        // External Link Event - should not reach this screen
                        externalLinkSection
                    } else if hasFreePricing {
                        // Free Event RSVP
                        freeEventSection
                    } else {
                        // Paid Event Ticket Selection
                        paidEventSection
                    }
                    
                    Spacer(minLength: 32)
                    
                    // Action Buttons
                    actionButtonsSection
                }
                .padding()
            }
            .navigationTitle("Reserve Event")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.espresso)
                }
            }
        }
        .alert("Reservation Confirmed", isPresented: $showReservationConfirmation) {
            Button("OK") {
                dismiss()
            }
        } message: {
            Text("Your RSVP for \(event.title) has been confirmed!")
        }
        .alert("Payment Error", isPresented: $showPaymentError) {
            Button("OK") {
                showPaymentError = false
                paymentErrorMessage = ""
            }
        } message: {
            Text(paymentErrorMessage)
        }
        .sheet(isPresented: $showPaymentSuccess) {
            PaymentSuccessView(event: event, selectedPrice: selectedPrice, quantity: quantity) {
                dismiss()
            }
        }
        .sheet(isPresented: $showExternalWebView) {
            if let externalLink = event.firstExternalLink, let url = URL(string: externalLink) {
                NavigationView {
                    WebView(url: url)
                        .navigationTitle("Event Tickets")
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .navigationBarTrailing) {
                                Button("Done") {
                                    showExternalWebView = false
                                }
                                .foregroundColor(.espresso)
                            }
                        }
                }
            }
        }
        .modifier(
            ConditionalPaymentSheetModifier(
                isPresented: $showPaymentSheet,
                paymentSheet: paymentSheet,
                onCompletion: handlePaymentResult
            )
        )
    }
    
    // MARK: - External Link Section
    
    private var externalLinkSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Third Party Event")
                .font(.headline)
                .foregroundColor(.espresso)
            
            VStack(alignment: .leading, spacing: 12) {
                Text("This is a third party event. Tickets must be purchased from the external host website.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                HStack {
                    Image(systemName: "link")
                        .foregroundColor(.blue)
                    Text("Visit external ticket site")
                        .font(.subheadline)
                }
                
                HStack {
                    Image(systemName: "info.circle")
                        .foregroundColor(.orange)
                    Text("Reservations are handled by the event host's website")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
                
                // External link button
                if let externalLink = event.firstExternalLink {
                    Button("Open Ticket Website") {
                        showExternalWebView = true
                    }
                    .buttonStyle(.bordered)
                    .tint(.blue)
                    .padding(.top, 8)
                }
            }
        }
        .padding(.vertical)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.orange.opacity(0.1))
        )
    }
    
    // MARK: - Free Event Section
    
    private var freeEventSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Free Event RSVP")
                .font(.headline)
                .foregroundColor(.espresso)
            
            VStack(alignment: .leading, spacing: 12) {
                Text("This is a free event! Simply confirm your attendance below.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("No payment required")
                        .font(.subheadline)
                }
                
                HStack {
                    Image(systemName: "person.2.fill")
                        .foregroundColor(.sandstone)
                    Text("Join other attendees")
                        .font(.subheadline)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.green.opacity(0.1))
        )
    }
    
    // MARK: - Paid Event Section
    
    private var paidEventSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Price Selection
            VStack(alignment: .leading, spacing: 16) {
                Text("Select Ticket Type")
                    .font(.headline)
                    .foregroundColor(.espresso)
                
                LazyVStack(spacing: 12) {
                    ForEach(event.priceDetails.indices, id: \.self) { index in
                        let priceDetail = event.priceDetails[index]
                        PriceOptionView(
                            priceDetail: priceDetail,
                            isSelected: selectedPriceIndex == index
                        ) {
                            selectedPriceIndex = index
                        }
                    }
                }
            }
            
            // Quantity Selection (only if a price is selected)
            if selectedPriceIndex != nil {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Number of Tickets")
                        .font(.headline)
                        .foregroundColor(.espresso)
                    
                    HStack {
                        Button {
                            if quantity > 1 {
                                quantity -= 1
                            }
                        } label: {
                            Image(systemName: "minus")
                                .font(.title2)
                                .foregroundColor(quantity > 1 ? .sandstone : .gray)
                                .frame(width: 44, height: 44)
                                .background(Color(.systemGray5))
                                .clipShape(Circle())
                        }
                        .disabled(quantity <= 1)
                        
                        Spacer()
                        
                        Text("\(quantity)")
                            .font(.title2)
                            .fontWeight(.semibold)
                            .frame(minWidth: 40)
                        
                        Spacer()
                        
                        Button {
                            if quantity < 10 {
                                quantity += 1
                            }
                        } label: {
                            Image(systemName: "plus")
                                .font(.title2)
                                .foregroundColor(quantity < 10 ? .sandstone : .gray)
                                .frame(width: 44, height: 44)
                                .background(Color(.systemGray5))
                                .clipShape(Circle())
                        }
                        .disabled(quantity >= 10)
                    }
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(.systemGray6))
                )
                
                // Total Calculation
                VStack(alignment: .leading, spacing: 12) {
                    Text("Order Summary")
                        .font(.headline)
                        .foregroundColor(.espresso)
                    
                    if let selectedPrice = selectedPrice {
                        HStack {
                            Text("\(selectedPrice.title) × \(quantity)")
                            Spacer()
                            Text(formatCurrency(selectedPrice.price * Decimal(quantity)))
                                .fontWeight(.semibold)
                        }
                        
                        Divider()
                        
                        HStack {
                            Text("Total")
                                .font(.title3)
                                .fontWeight(.bold)
                            Spacer()
                            Text(formatCurrency(totalAmount))
                                .font(.title3)
                                .fontWeight(.bold)
                                .foregroundColor(.sandstone)
                        }
                    }
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(.systemGray6))
                )
            }
        }
    }
    
    // MARK: - Action Buttons
    private var actionButtonsSection: some View {
        VStack(spacing: 16) {
            if hasExternalLinks {
                if event.firstExternalLink != nil {
                    Button("Open Ticket Website") {
                        showExternalWebView = true
                    }
                    .buttonStyle(PrimaryButtonStyle())
                }
                
                Button("Close") {
                    dismiss()
                }
                .foregroundColor(.secondary)
                .padding()
            } else if isProcessingPayment {
                ProgressView("Processing...")
                    .frame(maxWidth: .infinity, minHeight: 50)
                    .background(Color(.systemGray5))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            } else if hasFreePricing {
                Button("Confirm RSVP") {
                    confirmFreeReservation()
                }
                .buttonStyle(PrimaryButtonStyle())
            } else {
                Button(actionButtonTitle) {
                    if selectedPriceIndex != nil {
                        processPaidReservation()
                    }
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(selectedPriceIndex == nil)
            }
            
            Button("Cancel") {
                dismiss()
            }
            .foregroundColor(.secondary)
            .padding()
        }
    }
    
    private var actionButtonTitle: String {
        if selectedPriceIndex == nil {
            return "Select Ticket Type"
        } else {
            return "Purchase - \(formatCurrency(totalAmount))"
        }
    }
    
    // MARK: - Actions
    private func confirmFreeReservation() {
        // Call the reservation success callback to update the parent view
        onReservationSuccess?()
        // Show confirmation alert
        showReservationConfirmation = true
    }
    
    private func processPaidReservation() {
        guard let selectedPrice = selectedPrice,
              let userEmail = authenticationModel.state.currentUser?.email else {
            paymentErrorMessage = "Unable to process payment. Please try again."
            showPaymentError = true
            return
        }
        
        isProcessingPayment = true
        
        Task {
            do {
                // Create real PaymentSheet using new UUID-compatible endpoint
                let (paymentSheetInstance, orderIdFromBackend) = try await paymentService.createPaymentSheetForEvent(
                    event: event,
                    priceDetail: selectedPrice,
                    quantity: quantity,
                    userEmail: userEmail
                )
                
                await MainActor.run {
                    print("🔍 Setting paymentSheet = \(paymentSheetInstance)")
                    paymentSheet = paymentSheetInstance
                    paymentIntentId = orderIdFromBackend // Store the order ID for later use
                    
                    // Store the order immediately after successful backend response
                    // This ensures we have the correct order ID regardless of payment completion
                    let orderIdString = orderIdFromBackend.hasPrefix("pi_") ? String(orderIdFromBackend.dropFirst(3)) : orderIdFromBackend
                    if let userId = authenticationModel.state.currentUser?.id,
                       let orderId = Int(orderIdString) {
                        userOrdersService.storeOrder(
                            eventId: event.id.uuidString,
                            userId: userId,
                            orderId: orderId,
                            ticketCount: quantity
                        )
                        print("💾 Pre-stored order \(orderId) for event \(event.id.uuidString) before payment")
                    }
                    
                    isProcessingPayment = false // Allow PaymentSheet to show
                    
                    print("🔍 About to set showPaymentSheet = true")
                    print("🔍 Current showPaymentSheet value: \(showPaymentSheet)")
                    print("🔍 Current paymentSheet is nil: \(paymentSheet == nil)")
                    
                    // First set to false to ensure clean state
                    showPaymentSheet = false
                    
                    // Then set to true after a brief delay to ensure proper binding
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        print("🔍 Now setting showPaymentSheet = true with delay")
                        showPaymentSheet = true
                        print("🔍 After delayed setting, showPaymentSheet = \(showPaymentSheet)")
                    }
                    
                    print("✨ REAL PaymentSheet ready for UUID event: \(event.id.uuidString)")
                }
                
            } catch {
                await MainActor.run {
                    isProcessingPayment = false
                    paymentErrorMessage = error.localizedDescription
                    showPaymentError = true
                }
            }
        }
    }
    
    // MARK: - Real PaymentSheet Handler
    
    private func handlePaymentResult(_ result: PaymentSheetResult) {
        print("💰 REAL payment result received: \(result)")
        
        switch result {
        case .completed:
            print("✅ REAL payment completed successfully!")
            isProcessingPayment = false
            
            // Order already stored when payment sheet was created
            // No need to store again here
            
            // Call the reservation success callback to update the parent view
            onReservationSuccess?()
            
            // Real payment confirmation
            if let intentId = paymentIntentId {
                print("💾 Real payment confirmed with intent: \(intentId)")
            }
            showPaymentSuccess = true
            
        case .canceled:
            print("❌ Real payment was cancelled by user")
            isProcessingPayment = false
            
        case .failed(let error):
            print("🚨 Real payment failed: \(error.localizedDescription)")
            isProcessingPayment = false
            paymentErrorMessage = error.localizedDescription
            showPaymentError = true
        }
    }
    
    // MARK: - Helper Methods
    
    private func formatCurrency(_ amount: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        return formatter.string(from: NSDecimalNumber(decimal: amount)) ?? "$0.00"
    }
}

// MARK: - Price Option View

struct PriceOptionView: View {
    let priceDetail: PriceDetails
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(priceDetail.title)
                            .font(.headline)
                            .foregroundColor(.espresso)
                        
                        Spacer()
                        
                        Text(priceDetail.formattedPrice)
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundColor(.sandstone)
                    }
                    
                    if let description = priceDetail.description {
                        Text(description)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    // Show availability if limited
                    if let remaining = priceDetail.remainingQuantity {
                        HStack {
                            Image(systemName: "clock")
                                .foregroundColor(.orange)
                            Text("\(remaining) tickets remaining")
                                .font(.caption)
                                .foregroundColor(.orange)
                        }
                    }
                }
                
                Spacer()
                
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isSelected ? .sandstone : .gray)
                    .font(.title2)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.sandstone : Color(.systemGray4), lineWidth: isSelected ? 2 : 1)
                    .fill(isSelected ? Color.sandstone.opacity(0.1) : Color.clear)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Payment Success View

struct PaymentSuccessView: View {
    let event: Event
    let selectedPrice: PriceDetails?
    let quantity: Int
    let onDismiss: () -> Void
    
    var body: some View {
        VStack(spacing: 24) {
            // Success Icon
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 80))
                .foregroundColor(.green)
            
            // Success Message
            VStack(spacing: 12) {
                Text("Payment Successful!")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(.espresso)
                
                Text("Your reservation for \(event.title) has been confirmed.")
                    .font(.headline)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
            }
            
            // Order Details
            if let selectedPrice = selectedPrice {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Order Details")
                        .font(.headline)
                        .foregroundColor(.espresso)
                    
                    HStack {
                        Text("Event:")
                        Spacer()
                        Text(event.title)
                            .fontWeight(.semibold)
                    }
                    
                    HStack {
                        Text("Ticket Type:")
                        Spacer()
                        Text(selectedPrice.title)
                            .fontWeight(.semibold)
                    }
                    
                    HStack {
                        Text("Quantity:")
                        Spacer()
                        Text("\(quantity)")
                            .fontWeight(.semibold)
                    }
                    
                    Divider()
                    
                    HStack {
                        Text("Total Paid:")
                        Spacer()
                        Text(formatCurrency(selectedPrice.price * Decimal(quantity)))
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundColor(.sandstone)
                    }
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(.systemGray6))
                )
            }
            
            Spacer()
            
            // Action Buttons
            VStack(spacing: 12) {
                Button("View My Reservation") {
                    // TODO: Navigate to user's reservations
                    onDismiss()
                }
                .buttonStyle(PrimaryButtonStyle())
            }
        }
        .padding()
        .navigationBarHidden(true)
    }
    
    private func formatCurrency(_ amount: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        return formatter.string(from: NSDecimalNumber(decimal: amount)) ?? "$0.00"
    }
}

// MARK: - Primary Button Style

//struct PrimaryButtonStyle: ButtonStyle {
//    func makeBody(configuration: Configuration) -> some View {
//        configuration.label
//            .font(.headline)
//            .foregroundColor(.white)
//            .frame(maxWidth: .infinity, minHeight: 50)
//            .background(
//                LinearGradient(
//                    gradient: Gradient(colors: [.sandstone, .espresso]),
//                    startPoint: .leading,
//                    endPoint: .trailing
//                )
//            )
//            .clipShape(RoundedRectangle(cornerRadius: 12))
//            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
//            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
//    }
//}

// MARK: - Conditional PaymentSheet Modifier

private struct ConditionalPaymentSheetModifier: ViewModifier {
    @Binding var isPresented: Bool
    let paymentSheet: PaymentSheet?
    let onCompletion: (PaymentSheetResult) -> Void

    @ViewBuilder
    func body(content: Content) -> some View {
        let _ = print("🔴 ConditionalPaymentSheetModifier.body called - paymentSheet: \(paymentSheet != nil ? "NOT NIL" : "NIL"), isPresented: \(isPresented)")
        
        if let paymentSheet {
            let _ = print("🔴 PaymentSheet exists, applying .paymentSheet() modifier")
            content.paymentSheet(
                isPresented: $isPresented,
                paymentSheet: paymentSheet,
                onCompletion: { result in
                    print("🔍 Real PaymentSheet completed with result: \(result)")
                    onCompletion(result)
                }
            )
            .onAppear {
                print("🔍 Real PaymentSheet attached to content")
            }
            .onChange(of: isPresented) { oldValue, newValue in
                print("🔍 Real PaymentSheet isPresented: \(oldValue) → \(newValue)")
                if newValue {
                    print("🟢 PaymentSheet should be VISIBLE now!")
                }
            }
        } else {
            let _ = print("🔴 No PaymentSheet available, returning content unchanged")
            content
                .onAppear {
                    print("🔍 No PaymentSheet available yet")
                }
        }
    }
}

#Preview {
    ReservationSheet(
        event: {
            var e = try! Event(
                id: UUID(),
                title: "Summer Music Festival",
                description: "Join us for an amazing evening of music and fun!",
                date: "July 15, 2024",
                timeRange: "7:00 PM - 11:00 PM",
                location: "Central Park, NYC",
                createdBy: "host123"
            )
            e.addPriceDetail(try! PriceDetails(title: "General Admission", price: 25.00, currency: .usd, type: .fixed))
            e.addPriceDetail(try! PriceDetails(title: "VIP Access", price: 75.00, currency: .usd, type: .fixed))
            return e
        }(),
        onReservationSuccess: {}
    )
    .environmentObject(
        AuthenticationModel(
            authenticationService: ReservationSheetMockAuthService(),
            state: AppState()
        )
    )
}

// MARK: - Mock Service for Preview
struct ReservationSheetMockAuthService: AuthenticationService {
    func signUp(email: String, password: String) -> Future<AuthUser?, Error> {
        Future { promise in
            promise(.success(nil))
        }
    }
    
    func signIn(email: String, password: String) -> Future<AuthUser?, Error> {
        Future { promise in
            let mockUser = AuthUser(id: "mock-id", email: email, isNewUser: false)
            promise(.success(mockUser))
        }
    }
    
    func signOut() -> Future<Void, Never> {
        Future { promise in
            promise(.success(()))
        }
    }
    
    func updateCurrentUserPassword(email: String, password: String, newPassword: String) -> Future<Void, Error> {
        Future { promise in
            promise(.success(()))
        }
    }
    
    func deleteCurrentUser(email: String, password: String) -> Future<Void, Error> {
        Future { promise in
            promise(.success(()))
        }
    }
}

