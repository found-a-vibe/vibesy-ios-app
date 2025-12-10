//
//  InvoiceDisplayView.swift
//  Vibesy
//
//  Created by Alexander Cleoni on Invoice Integration.
//

import SwiftUI

struct InvoiceDisplayView: View {
    let qrInvoiceData: QRInvoiceData
    @SwiftUI.Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = InvoiceDisplayViewModel()
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Header
                    VStack(spacing: 12) {
                        Image(systemName: "doc.text")
                            .font(.system(size: 50))
                            .foregroundColor(.goldenBrown)
                        
                        Text("Payment Receipt")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.goldenBrown)
                    }
                    .padding(.top)
                    
                    // Event Information
                    InvoiceSection(title: "Event Details") {
                        VStack(spacing: 8) {
                            InvoiceRow(label: "Event", value: qrInvoiceData.eventTitle)
                            
                            if let ticketType = qrInvoiceData.ticketType {
                                InvoiceRow(label: "Ticket Type", value: ticketType)
                            }
                            
                            InvoiceRow(label: "Quantity", value: "\(qrInvoiceData.quantity)")
                        }
                    }
                    
                    // Payment Information
                    InvoiceSection(title: "Payment Details") {
                        VStack(spacing: 8) {
                            InvoiceRow(label: "Amount Paid", value: formatCurrency(qrInvoiceData.amountPaid, currency: qrInvoiceData.currency))
                            
                            InvoiceRow(label: "Payment Date", value: formatDate(qrInvoiceData.paymentDate))
                            
                            if let customerEmail = qrInvoiceData.customerEmail {
                                InvoiceRow(label: "Customer Email", value: customerEmail)
                            }
                            
                            if let paymentIntentId = qrInvoiceData.paymentIntentId {
                                InvoiceRow(label: "Transaction ID", value: paymentIntentId)
                            }
                        }
                    }
                    
                    // Receipt URL Section (if available)
                    if let receiptURL = qrInvoiceData.receiptURL {
                        InvoiceSection(title: "Receipt") {
                            VStack(spacing: 12) {
                                Text("A detailed receipt is available online")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                                
                                Button("View Full Receipt") {
                                    openReceiptURL(receiptURL)
                                }
                                .buttonStyle(PrimaryButtonStyle())
                            }
                        }
                    }
                    
                    // Additional Invoice Details (if available)
                    if viewModel.invoiceDetails != nil {
                        InvoiceSection(title: "Invoice Details") {
                            if let invoice = viewModel.invoiceDetails {
                                VStack(spacing: 8) {
                                    if let receiptNumber = invoice.receiptNumber {
                                        InvoiceRow(label: "Receipt Number", value: receiptNumber)
                                    }
                                    
                                    InvoiceRow(label: "Status", value: invoice.status.capitalized)
                                    
                                    if let description = invoice.description {
                                        InvoiceRow(label: "Description", value: description)
                                    }
                                }
                            }
                        }
                    }
                    
                    Spacer(minLength: 20)
                }
                .padding()
            }
            .navigationTitle("Receipt")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(.espresso)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        if let receiptURL = qrInvoiceData.receiptURL {
                            Button {
                                shareReceipt(receiptURL)
                            } label: {
                                Label("Share Receipt", systemImage: "square.and.arrow.up")
                            }
                        }
                        
                        Button {
                            copyTransactionDetails()
                        } label: {
                            Label("Copy Transaction ID", systemImage: "doc.on.doc")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
        }
        .task {
            await viewModel.loadInvoiceDetails(for: qrInvoiceData)
        }
    }
    
    private func formatCurrency(_ cents: Int, currency: String) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currency.uppercased()
        return formatter.string(from: NSNumber(value: Double(cents) / 100.0)) ?? "$0.00"
    }
    
    private func formatDate(_ dateString: String) -> String {
        let formatter = ISO8601DateFormatter()
        guard let date = formatter.date(from: dateString) else {
            return dateString
        }
        
        let displayFormatter = DateFormatter()
        displayFormatter.dateStyle = .medium
        displayFormatter.timeStyle = .short
        return displayFormatter.string(from: date)
    }
    
    private func openReceiptURL(_ urlString: String) {
        guard let url = URL(string: urlString) else { return }
        UIApplication.shared.open(url)
    }
    
    private func shareReceipt(_ urlString: String) {
        guard let url = URL(string: urlString) else { return }
        
        let activityController = UIActivityViewController(
            activityItems: [url],
            applicationActivities: nil
        )
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first {
            window.rootViewController?.present(activityController, animated: true)
        }
    }
    
    private func copyTransactionDetails() {
        var details = "Transaction Details\n\n"
        details += "Event: \(qrInvoiceData.eventTitle)\n"
        details += "Amount: \(formatCurrency(qrInvoiceData.amountPaid, currency: qrInvoiceData.currency))\n"
        details += "Date: \(formatDate(qrInvoiceData.paymentDate))\n"
        
        if let paymentIntentId = qrInvoiceData.paymentIntentId {
            details += "Transaction ID: \(paymentIntentId)\n"
        }
        
        UIPasteboard.general.string = details
    }
}

// MARK: - Invoice Section View

struct InvoiceSection<Content: View>: View {
    let title: String
    let content: Content
    
    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
                .foregroundColor(.espresso)
            
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray6))
        )
    }
}

// MARK: - Invoice Row View

struct InvoiceRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.primary)
                .multilineTextAlignment(.trailing)
        }
    }
}
// MARK: - ViewModel

@MainActor
class InvoiceDisplayViewModel: ObservableObject {
    @Published var invoiceDetails: StripeInvoiceDetail?
    @Published var paymentReceipt: PaymentReceiptDetail?
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let apiService = StripeAPIService.shared
    
    func loadInvoiceDetails(for qrData: QRInvoiceData) async {
        guard let paymentIntentId = qrData.paymentIntentId, !paymentIntentId.isEmpty else { 
            print("⚠️ No valid payment intent ID available for invoice details")
            return 
        }
        
        isLoading = true
        errorMessage = nil
        
        print("🔄 Loading invoice details for payment intent: \(paymentIntentId)")
        
        // Try to load invoice details first
        do {
            let invoiceResponse = try await apiService.getInvoiceDetails(paymentIntentId: paymentIntentId)
            if invoiceResponse.success, let invoice = invoiceResponse.invoice {
                invoiceDetails = invoice
                print("✅ Successfully loaded invoice details")
            } else {
                print("⚠️ Invoice response was not successful or empty")
                await loadReceiptAsFallback(paymentIntentId: paymentIntentId)
            }
        } catch {
            print("❌ Failed to load invoice details: \(error.localizedDescription)")
            // If invoice details fail, try payment receipt as fallback
            await loadReceiptAsFallback(paymentIntentId: paymentIntentId)
        }
        
        isLoading = false
    }
    
    private func loadReceiptAsFallback(paymentIntentId: String) async {
        print("🔄 Trying to load payment receipt as fallback...")
        do {
            let receiptResponse = try await apiService.getPaymentReceipt(paymentIntentId: paymentIntentId)
            if receiptResponse.success, let receipt = receiptResponse.receipt {
                paymentReceipt = receipt
                print("✅ Successfully loaded payment receipt")
            } else {
                print("⚠️ Receipt response was not successful or empty")
                errorMessage = "Unable to load payment details"
            }
        } catch {
            print("❌ Failed to load payment receipt: \(error.localizedDescription)")
            errorMessage = "Unable to load additional payment details: \(error.localizedDescription)"
        }
    }
}

// MARK: - Preview

#Preview {
    InvoiceDisplayView(
        qrInvoiceData: QRInvoiceData(
            ticketToken: "sample_token",
            invoiceId: "in_sample123",
            paymentIntentId: "pi_sample123",
            receiptURL: "https://example.com/receipt",
            amountPaid: 2500, // $25.00
            currency: "usd",
            paymentDate: "2024-01-15T10:30:00Z",
            customerEmail: "user@example.com",
            eventTitle: "Summer Music Festival",
            ticketType: "General Admission",
            quantity: 2
        )
    )
}
