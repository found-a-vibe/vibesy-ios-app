//
//  TicketListView.swift
//  Vibesy
//
//  Created by Alexander Cleoni on Payment Integration.
//

import SwiftUI
import CoreImage.CIFilterBuiltins

struct TicketListView: View {
    @StateObject private var viewModel = TicketListViewModel()
    @SwiftUI.Environment(\.dismiss) private var dismiss
    
    let orderId: Int
    
    var body: some View {
        NavigationView {
            Group {
                if viewModel.isLoading {
                    ProgressView("Loading tickets...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let orderResponse = viewModel.orderResponse {
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            // Order Summary
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Order Summary")
                                    .font(.headline)
                                
                                HStack {
                                    Text("Order ID:")
                                    Spacer()
                                    Text("#\(orderResponse.order.id)")
                                        .fontWeight(.medium)
                                }
                                
                                HStack {
                                    Text("Status:")
                                    Spacer()
                                    Text(orderResponse.order.status.capitalized)
                                        .fontWeight(.medium)
                                        .foregroundColor(orderResponse.order.status == "completed" ? .green : .orange)
                                }
                                
                                HStack {
                                    Text("Total:")
                                    Spacer()
                                    Text(formatCurrency(orderResponse.order.amountCents))
                                        .fontWeight(.bold)
                                }
                            }
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color(.systemGray6))
                            )
                            
                            // Tickets
                            ForEach(orderResponse.tickets) { ticket in
                                TicketCardView(ticket: ticket)
                            }
                        }
                        .padding()
                    }
                } else {
                    ContentUnavailableView(
                        "No Tickets Found",
                        systemImage: "ticket",
                        description: Text("Unable to load tickets for this order.")
                    )
                }
            }
            .navigationTitle("Your Tickets")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                }
                
//                if viewModel.orderResponse != nil {
//                    ToolbarItem(placement: .navigationBarTrailing) {
//                        Menu {
//                            Button {
//                                viewModel.shareTickets()
//                            } label: {
//                                Label("Share Tickets", systemImage: "square.and.arrow.up")
//                            }
//                            
//                            Button {
//                                viewModel.saveToPhotos()
//                            } label: {
//                                Label("Save to Photos", systemImage: "photo")
//                            }
//                        } label: {
//                            Image(systemName: "ellipsis.circle")
//                        }
//                    }
//                }
            }
            .alert("Error", isPresented: .constant(viewModel.errorMessage != nil)) {
                Button("OK") {
                    viewModel.errorMessage = nil
                }
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
        }
        .task {
            await viewModel.loadTickets(orderId: orderId)
        }
    }
    
    private func formatCurrency(_ cents: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        return formatter.string(from: NSNumber(value: Double(cents) / 100.0)) ?? "$0.00"
    }
}

struct TicketCardView: View {
    let ticket: TicketInfo
    @State private var showingQRCode = false
    @State private var showingInvoice = false
    @State private var qrInvoiceData: QRInvoiceData?
    @State private var isLoadingInvoice = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Ticket Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(ticket.event.title)
                        .font(.headline)
                        .fontWeight(.bold)
                    
                    Text(ticket.ticketNumber)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    StatusBadge(status: ticket.status)
                    
                    if ticket.status == "used", let scannedAt = ticket.scannedAt {
                        Text("Scanned at \(scannedAt)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            // Event Details
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "location")
                        .foregroundColor(.secondary)
                    Text(ticket.event.venue)
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    Image(systemName: "calendar")
                        .foregroundColor(.secondary)
                    Text(formatEventDate(ticket.event.startsAt))
                        .foregroundColor(.secondary)
                }
                
                if let holderName = ticket.holderName {
                    HStack {
                        Image(systemName: "person")
                            .foregroundColor(.secondary)
                        Text(holderName)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Divider()
            
            // Actions
            HStack {
//                Button {
//                    showingQRCode.toggle()
//                } label: {
//                    HStack {
//                        Image(systemName: "qrcode")
//                        Text(showingQRCode ? "Hide QR Code" : "Show QR Code")
//                    }
//                    .font(.subheadline)
//                    .fontWeight(.medium)
//                }
//                .foregroundColor(.blue)
//                
//                Spacer()
                
                // Invoice button (only for paid tickets)
                if ticket.event.priceCents > 0 {
                    Button {
                        if qrInvoiceData != nil {
                            showingInvoice = true
                        } else {
                            loadInvoiceData()
                        }
                    } label: {
                        HStack {
                            if isLoadingInvoice {
                                ProgressView()
                                    .scaleEffect(0.8)
                            } else {
                                Image(systemName: "doc.text")
                            }
                            Text("Receipt")
                        }
                        .font(.subheadline)
                        .fontWeight(.medium)
                    }
                    .foregroundColor(.green)
                    .disabled(isLoadingInvoice)
                    
                    Spacer()
                }
                
                Button {
                    shareTicket(ticket)
                } label: {
                    Image(systemName: "square.and.arrow.up")
                        .font(.title3)
                }
                .foregroundColor(.blue)
            }
            
            // QR Code
            if showingQRCode {
                VStack(spacing: 12) {
                    if let invoiceData = qrInvoiceData {
                        QRCodeView(invoiceData: invoiceData)
                            .frame(width: 200, height: 200)
                    } else {
                        QRCodeView(token: ticket.qrToken)
                            .frame(width: 200, height: 200)
                    }
                    
                    VStack(spacing: 4) {
                        Text("Present this QR code at the event entrance")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                        
                        if qrInvoiceData != nil {
                            Text("QR code includes payment receipt information")
                                .font(.caption2)
                                .foregroundColor(.green)
                                .multilineTextAlignment(.center)
                        }
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.top)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
        )
        .sheet(isPresented: $showingInvoice) {
            if let invoiceData = qrInvoiceData {
                InvoiceDisplayView(qrInvoiceData: invoiceData)
            }
        }
        .onAppear {
            // Preload invoice data for paid tickets
            if ticket.event.priceCents > 0 && qrInvoiceData == nil {
                loadInvoiceData()
            }
        }
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
    
    private func loadInvoiceData() {
        guard !isLoadingInvoice else { 
            print("🔄 Already loading invoice data for ticket \(ticket.id)")
            return 
        }
        
        print("🚀 Starting to load invoice data for ticket \(ticket.id)")
        isLoadingInvoice = true
        
        Task {
            do {
                let invoiceData = try await StripeAPIService.shared.getTicketQRWithInvoice(ticketId: ticket.id)
                
                await MainActor.run {
                    self.qrInvoiceData = invoiceData
                    self.isLoadingInvoice = false
                    print("✅ Successfully loaded invoice data for ticket \(ticket.id)")
                }
            } catch {
                await MainActor.run {
                    self.isLoadingInvoice = false
                    print("❌ Failed to load invoice data for ticket \(ticket.id): \(error.localizedDescription)")
                    
                    // Show user-friendly error message
                    if let apiError = error as? APIError {
                        switch apiError {
                        case .networkError(_):
                            print("🌐 Network error - invoice data may not be available")
                        case .serverError(let message):
                            print("🔧 Server error: \(message)")
                        case .invalidResponse:
                            print("📄 Invalid response from server")
                        }
                    }
                }
            }
        }
    }
    
    private func shareTicket(_ ticket: TicketInfo) {
        var shareItems: [Any] = []
        
        // Add basic ticket information
        let ticketInfo = "\(ticket.event.title)\nTicket: \(ticket.ticketNumber)\nVenue: \(ticket.event.venue)\nDate: \(formatEventDate(ticket.event.startsAt))"
        shareItems.append(ticketInfo)
        
        // Add receipt URL if available
        if let invoiceData = qrInvoiceData, let receiptURL = invoiceData.receiptURL {
            shareItems.append(URL(string: receiptURL)!)
        }
        
        let activityController = UIActivityViewController(
            activityItems: shareItems,
            applicationActivities: nil
        )
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first {
            window.rootViewController?.present(activityController, animated: true)
        }
    }
}

struct StatusBadge: View {
    let status: String
    
    var statusColor: Color {
        switch status.lowercased() {
        case "valid":
            return .green
        case "used":
            return .gray
        case "cancelled", "refunded":
            return .red
        default:
            return .orange
        }
    }
    
    var body: some View {
        Text(status.capitalized)
            .font(.caption)
            .fontWeight(.semibold)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(statusColor.opacity(0.2))
            )
            .foregroundColor(statusColor)
    }
}

struct QRCodeView: View {
    let token: String
    let invoiceData: QRInvoiceData?
    
    // Convenience initializer for simple token
    init(token: String) {
        self.token = token
        self.invoiceData = nil
    }
    
    // Initializer for invoice data
    init(invoiceData: QRInvoiceData) {
        self.token = invoiceData.ticketToken
        self.invoiceData = invoiceData
    }
    
    var body: some View {
        Image(uiImage: generateQRCode())
            .interpolation(.none)
            .resizable()
            .scaledToFit()
    }
    
    private func generateQRCode() -> UIImage {
        let context = CIContext()
        let filter = CIFilter.qrCodeGenerator()
        
        let qrContent: String
        
        if let invoiceData = invoiceData {
            // Generate QR code with invoice data as JSON
            do {
                let encoder = JSONEncoder()
                encoder.outputFormatting = .prettyPrinted
                let jsonData = try encoder.encode(invoiceData)
                qrContent = String(data: jsonData, encoding: .utf8) ?? token
            } catch {
                print("Failed to encode invoice data: \(error)")
                qrContent = token // Fallback to simple token
            }
        } else {
            // Use simple token format
            qrContent = token
        }
        
        filter.message = Data(qrContent.utf8)
        
        if let outputImage = filter.outputImage {
            // Scale up the QR code for better quality
            let scaleFilter = CIFilter.lanczosScaleTransform()
            scaleFilter.inputImage = outputImage
            scaleFilter.scale = 10.0
            
            if let scaledImage = scaleFilter.outputImage,
               let cgImage = context.createCGImage(scaledImage, from: scaledImage.extent) {
                return UIImage(cgImage: cgImage)
            }
        }
        
        return UIImage(systemName: "xmark.circle") ?? UIImage()
    }
}

// MARK: - ViewModel

@MainActor
class TicketListViewModel: ObservableObject {
    @Published var orderResponse: OrderTicketsResponse?
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let apiService = StripeAPIService.shared
    
    func loadTickets(orderId: Int) async {
        isLoading = true
        errorMessage = nil
        
        do {
            orderResponse = try await apiService.getOrderTickets(orderId: orderId)
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
    
    func shareTickets() {
        // Implementation for sharing all tickets
        // This could create a PDF or image with all tickets
    }
    
    func saveToPhotos() {
        // Implementation for saving tickets to photo library
        // Would need to request photo library permissions
    }
}

// MARK: - Preview

#Preview {
    TicketListView(orderId: 123)
}
