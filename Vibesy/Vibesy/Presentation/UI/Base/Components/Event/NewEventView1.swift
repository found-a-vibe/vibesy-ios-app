//
//  NewEvent.swift
//  FoundAVibe
//
//  Created by Alexander Cleoni on 11/22/24.
//

import SwiftUI
import PhotosUI
import Kingfisher

struct NewEventView1: View {
    @SwiftUI.Environment(\.dismiss) var dismiss
    @EnvironmentObject var eventModel: EventModel
    @EnvironmentObject var authenticationModel: AuthenticationModel
    @StateObject private var stripeStatusManager = StripeStatusManager.shared
    
    // Event Images
    @State private var selectedEventImages: [PhotosPickerItem] = []
    @State private var eventImages: [UIImage] = []
    
    // Guest Images
    @State private var selectedGuestImages: [PhotosPickerItem] = []
    @State private var guestSpeakers: [Guest] = []
    
    @State private var priceTitle: String = ""
    @State private var eventPrice: String = ""
    @State private var prices: [PriceDetails] = []
    
    @State private var speakerName: String = ""
    @State private var speakerRole: String = ""
    @State private var showAlert: Bool = false
    @State private var alertMessage: (String, String) = ("", "")
    
    @State private var innapropriateImageAlert: Bool = false
    
    @Binding var isNewEventViewPresented: Bool
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Back Button and Title
                HStack {
                    BackButtonView {
                        dismiss()
                    }
                    Spacer()
                    Text("Post Event")
                        .foregroundStyle(.espresso)
                        .font(.abeezeeItalic(size: 26))
                        .fontWeight(.semibold)
                    Spacer()
                }
                .padding(.horizontal)
                
                // Price Details Section
                priceDetailsSection()
                
                // Speaker/Guest Section
                guestSpeakersSection()
                
                eventImagesSection()
                
                // Post Button
                Button(action: {
                    Task {
                        // Existing validation and posting logic
                        if eventImages.count < 1 {
                            alertMessage = ("Event Image Required!", "Please upload at least one image of your event.")
                            showAlert.toggle()
                        } else {
                            // Attempt to merge into model's newEvent if present; otherwise just proceed to addEvent
                            if var newEvent = eventModel.newEvent {
                                let mergedImages = (newEvent.newImages) + eventImages
                                mergedImages.forEach { try? newEvent.addImage($0) }
                                // Debug: Check what we're working with
                                print("🔍 DEBUG: Local prices array has \(prices.count) items")
                                for (index, price) in prices.enumerated() {
                                    print("🔍   Price \(index): \(price.title) - \(price.formattedPrice)")
                                }
                                print("🔍 DEBUG: Event priceDetails has \(newEvent.priceDetails.count) items before merge")
                                
                                // Merge guests and price details
                                let mergedGuests = (newEvent.guests) + guestSpeakers
                                let mergedPrices = (newEvent.priceDetails) + prices
                                
                                print("🔍 DEBUG: mergedPrices has \(mergedPrices.count) items")
                                
                                // Write back into the model if properties are mutable
                                mergedGuests.forEach { try? newEvent.addGuest($0) }
                                mergedPrices.forEach { 
                                    print("🔍   Adding price detail: \($0.title) - \($0.formattedPrice)")
                                    newEvent.addPriceDetail($0) 
                                }
                                eventModel.newEvent = newEvent
                                
                                print("🔍 DEBUG: Event priceDetails has \(newEvent.priceDetails.count) items after merge")
                                
                                // Check if event has pricing AFTER merging
                                let hasPricing = !newEvent.priceDetails.isEmpty
                                
                                print("🔍 DEBUG: Event has \(newEvent.priceDetails.count) price details, hasPricing: \(hasPricing)")
                                
                                if hasPricing {
                                    // Validate Stripe onboarding for paid events
                                    let isOnboarded = await validateStripeOnboarding()
                                    print("🔍 DEBUG: Stripe onboarding status: \(isOnboarded)")
                                    if !isOnboarded {
                                        alertMessage = ("Stripe Setup Required", "To charge for events, you need to complete payment setup in Account Settings under Host Settings.")
                                        showAlert.toggle()
                                        return
                                    }
                                }
                                
                                // Create Stripe products if this is a paid event
                                if hasPricing, let userEmail = authenticationModel.state.currentUser?.email {
                                    print("🔍 DEBUG: Starting Stripe product creation for user: \(userEmail)")
                                    do {
                                        // Get Stripe connected account ID from status manager
                                        await stripeStatusManager.syncStripeStatus(email: userEmail)
                                        
                                        if let connectedAccountId = stripeStatusManager.stripeAccountId {
                                            print("🔍 DEBUG: Using connected account ID: \(connectedAccountId)")
                                            let stripeProductService = StripeProductService.shared
                                            let stripeInfo = try await stripeProductService.createEventProductWithPrices(
                                                event: newEvent,
                                                connectedAccountId: connectedAccountId
                                            )
                                            
                                            print("🎉 SUCCESS: Created Stripe product \(stripeInfo.productId) with \(stripeInfo.priceIds.count) prices")
                                            
                                            // Update the event with Stripe product information
                                            newEvent.setStripeProductInfo(
                                                productId: stripeInfo.productId,
                                                connectedAccountId: stripeInfo.connectedAccountId
                                            )
                                            
                                            // Update price details with Stripe price IDs
                                            var updatedPriceDetails = newEvent.priceDetails
                                            for (index, priceId) in stripeInfo.priceIds.enumerated() {
                                                if index < updatedPriceDetails.count {
                                                    updatedPriceDetails[index].setStripePriceId(priceId)
                                                    print("🔄 Updated price detail \(index) with Stripe price ID: \(priceId)")
                                                }
                                            }
                                            newEvent.updatePriceDetails(updatedPriceDetails)
                                            
                                            eventModel.newEvent = newEvent
                                        } else {
                                            alertMessage = ("Stripe Setup Error", "Unable to retrieve Stripe account information. Please check your account settings.")
                                            showAlert.toggle()
                                            return
                                        }
                                    } catch {
                                        print("🚨 ERROR: Stripe integration failed - \(error.localizedDescription)")
                                        print("🚨 Full error: \(error)")
                                        alertMessage = ("Stripe Integration Error", "Failed to create Stripe product: \(error.localizedDescription)")
                                        showAlert.toggle()
                                        return
                                    }
                                }
                            }
                            isNewEventViewPresented = false
                            Task { try await eventModel.addEvent() }
                        }
                    }
                }) {
                    Text("Post")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(.espresso)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                
                .padding(.horizontal)
            }
            .overlay(alignment: .center) {
                if showAlert {
                    buildAlert()
                }
            }
            .padding(.top)
        }
        .onTapGesture {
            hideKeyboard()
        }
        .scrollDismissesKeyboard(.interactively)
    }
    
    // MARK: - Section for Price Details
    @ViewBuilder
    private func priceDetailsSection() -> some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("Price Details").font(.headline)
            HStack(spacing: 10) {
                TextField("Enter Price Title", text: $priceTitle)
                    .padding()
                    .background(RoundedRectangle(cornerRadius: 10).stroke(Color.gray, lineWidth: 1))
                TextField("Enter Event Price", text: $eventPrice)
                    .keyboardType(.decimalPad)
                    .padding()
                    .background(RoundedRectangle(cornerRadius: 10).stroke(Color.gray, lineWidth: 1))
                Button(action: {
                    print("🔥 BUTTON TAPPED! Title: '\(priceTitle)', Price: '\(eventPrice)'")
                    addPrice()
                }) {
                    Image(systemName: "plus.circle.fill")
                        .foregroundColor(.sandstone)
                }
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(prices.indices, id: \.self) { index in
                        let price = prices[index]
                        HStack {
                            Text("\(price.title)\n\(price.formattedPrice)")
                                .multilineTextAlignment(.center)
                                .font(.abeezeeItalic(size: 16))
                                .padding(.vertical, 5)
                            Button(action: {
                                removePrice(price)
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.sandstone)
                            }
                        }
                        .padding()
                        .background(RoundedRectangle(cornerRadius: 10).stroke(Color.gray))
                    }
                }
            }
        }
        .padding(.horizontal)
    }
    
    // MARK: - Section for Guest Speakers
    @ViewBuilder
    private func guestSpeakersSection() -> some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("Guest Speakers").font(.headline)
            HStack(spacing: 10) {
                TextField("Enter Name", text: $speakerName)
                    .padding()
                    .background(RoundedRectangle(cornerRadius: 10).stroke(Color.gray, lineWidth: 1))
                TextField("Enter Role", text: $speakerRole)
                    .padding()
                    .background(RoundedRectangle(cornerRadius: 10).stroke(Color.gray, lineWidth: 1))
                PhotosPicker(selection: $selectedGuestImages, maxSelectionCount: 5, matching: .images) {
                    Image(systemName: "plus.circle.fill")
                        .foregroundColor(.sandstone)
                }
                .disabled(speakerName.isEmpty)
                .onChange(of: selectedGuestImages) { _, _ in
                    guard !speakerName.isEmpty else {
                        alertMessage = ("Speaker Name Required!", "Please enter a name for the guest speaker.")
                        showAlert.toggle()
                        selectedGuestImages.removeAll()
                        return
                    }
                    Task {
                        let loadedImages = await loadImages(from: selectedGuestImages)
                        if let lastImage = loadedImages.last {
                            addSpeaker(image: lastImage)
                        }
                    }
                }
            }
            ScrollView(.horizontal) {
                HStack {
                    ForEach(guestSpeakers, id: \.id) { speaker in
                        VStack(alignment: .center) {
                            if let url = speaker.getImageUrl {
                                KFImage(url)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 100, height: 100)
                                    .clipped()
                                    .cornerRadius(8)
                            }
                            HStack {
                                Text("\(speaker.name)\n\(speaker.role)")
                                    .multilineTextAlignment(.center)
                                    .font(.abeezeeItalic(size: 16))
                                    .padding(.vertical, 5)
                                Spacer()
                                Button(action: { removeSpeaker(speaker.name) }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(.sandstone)
                                }
                            }
                        }
                    }
                }
            }
        }
        .padding(.horizontal)
    }
    
    @ViewBuilder private func eventImagesSection() -> some View{
        // Event Images Picker
        VStack(alignment: .leading, spacing: 15) {
            Text("Event Images")
                .font(.headline)
            PhotosPicker("Upload Event Images", selection: $selectedEventImages, maxSelectionCount: 10, matching: .images)
                .font(.subheadline)
                .padding()
                .background(RoundedRectangle(cornerRadius: 10).stroke(Color.gray, lineWidth: 1))
                .onChange(of: selectedEventImages) { _, _ in
                    Task {
                        eventImages = await loadImages(from: selectedEventImages)
                    }
                }
            
            ScrollView(.horizontal) {
                HStack {
                    ForEach(eventImages.indices, id: \.self) { index in
                        Image(uiImage: eventImages[index])
                            .resizable()
                            .scaledToFill()
                            .frame(width: 100, height: 100)
                            .clipped()
                            .cornerRadius(8)
                    }
                }
            }
        }
        .padding(.horizontal)
    }
    
    @ViewBuilder private func buildAlert() -> some View {
        RoundedRectangle(cornerRadius: 20)
            .fill(
                LinearGradient (colors: [.sandstone, .goldenBrown, .espresso], startPoint: .topLeading, endPoint: .bottomTrailing)
            )
            .frame(maxWidth: 393, maxHeight: 155)
            .padding()
            .overlay {
                VStack(alignment: .center, spacing: 12) {
                    Text(alertMessage.0)
                        .font(.abeezeeItalic(size: 20))
                    Text(alertMessage.1)
                        .font(.abeezeeItalic(size: 14))
                        .multilineTextAlignment(.center)
                    Button(action: {
                        alertMessage = ("", "")
                        if innapropriateImageAlert == true {
                            innapropriateImageAlert = false
                        }
                        showAlert.toggle()
                    }) {
                        Text("Close")
                            .font(.headline)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.vertical)
                    }
                }
                .foregroundStyle(.white)
                .padding()
            }
            .animation(.easeInOut, value: showAlert)
    }
    
    @MainActor
    private func loadImages(from items: [PhotosPickerItem]) async -> [UIImage] {
        await withTaskGroup(of: UIImage?.self) { group in
            for item in items {
                group.addTask {
                    // Load image data
                    guard let data = try? await item.loadTransferable(type: Data.self),
                          let uiImage = UIImage(data: data) else {
                        return nil
                    }
                    
                    // Run the NSFW check once
                    let score = await uiImage.predictImage() ?? 1.0
                    if score <= 0.5 {
                        return uiImage // Safe image
                    } else {
                        await MainActor.run {
                            if let index = items.firstIndex(of: item) {
                                innapropriateImageAlert = true
                                alertMessage = ("NSFW Image Detected!", "One or more of your images was flagged for inappropriate content. For your safety and compliance, flagged images cannot be posted.")
                                showAlert.toggle()
                                // Remove from both possible selections
                                if selectedEventImages.indices.contains(index) { selectedEventImages.remove(at: index) }
                                if selectedGuestImages.indices.contains(index) { selectedGuestImages.remove(at: index) }
                            }
                        }
                        return nil
                    }
                }
            }
            
            // Collect results
            var results: [UIImage] = []
            for await image in group {
                if let image = image {
                    results.append(image)
                }
            }
            
            return results
        }
    }
    
    // MARK: - Helper Functions
    
    /// Validate Stripe onboarding for paid events
    private func validateStripeOnboarding() async -> Bool {
        guard let userEmail = authenticationModel.state.currentUser?.email else { return false }
        
        // Sync status from backend
        await stripeStatusManager.syncStripeStatus(email: userEmail)
        
        return stripeStatusManager.canCreatePaidEvents
    }
    
    private func addPrice() {
        print("🔍 addPrice() called - priceTitle: '\(priceTitle)', eventPrice: '\(eventPrice)'")
        
        guard !priceTitle.isEmpty, !eventPrice.isEmpty else { 
            print("🚨 addPrice() failed - empty title or price")
            return 
        }
        
        print("🔍 Validation passed, processing price...")
        
        // Normalize and parse the price
        let trimmed = eventPrice.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalized = trimmed.replacingOccurrences(of: "$", with: "")
        
        print("🔍 Normalized price string: '\(normalized)'")
        
        // Convert string to Decimal
        print("🔍 Attempting to convert '\(normalized)' to Decimal...")
        
        // Test various decimal formats
        let testFormats = [normalized, normalized.replacingOccurrences(of: ",", with: ".")]
        var decimal: Decimal?
        
        for format in testFormats {
            if let d = Decimal(string: format) {
                decimal = d
                print("🎉 Successfully converted '\(format)' to Decimal: \(d)")
                break
            } else {
                print("❌ Failed to convert '\(format)' to Decimal")
            }
        }
        
        guard let decimal = decimal else {
            print("🚨 All conversion attempts failed for input: '\(eventPrice)'")
            print("🚨 Normalized input: '\(normalized)'")
            alertMessage = ("Invalid Price", "Please enter a valid price amount (e.g., 12.50).")
            showAlert.toggle()
            return
        }
        
        print("🔍 Decimal conversion successful: \(decimal)")
        
        // Create PriceDetails instance
        do {
            let priceDetail = try PriceDetails(
                title: priceTitle.trimmingCharacters(in: .whitespacesAndNewlines),
                price: decimal,
                currency: .usd, // Default to USD, can be made configurable later
                type: .fixed
            )
            prices.append(priceDetail)
            print("🎉 SUCCESSFULLY ADDED PRICE: \(priceDetail.title) - \(priceDetail.formattedPrice) (Total: \(prices.count))")
            
            // Clear input fields
            priceTitle = ""
            eventPrice = ""
        } catch {
            print("🚨 PriceDetails creation failed: \(error.localizedDescription)")
            alertMessage = ("Invalid Price Details", error.localizedDescription)
            showAlert.toggle()
        }
    }
    
    private func removePrice(_ price: PriceDetails) {
        prices.removeAll { $0.title == price.title && $0.price == price.price }
    }
    
    private func addSpeaker(image: UIImage) {
        guard !speakerName.isEmpty else { return }
        
        // Create Guest instance
        do {
            let guest = try Guest(
                name: speakerName.trimmingCharacters(in: .whitespacesAndNewlines),
                role: speakerRole.isEmpty ? "Speaker" : speakerRole.trimmingCharacters(in: .whitespacesAndNewlines),
                imageUrl: nil // For now, we're not uploading the image to get a URL
            )
            guestSpeakers.append(guest)
            
            // Clear input fields
            speakerName = ""
            speakerRole = ""
        } catch {
            alertMessage = ("Invalid Speaker Details", error.localizedDescription)
            showAlert.toggle()
        }
    }
    
    private func removeSpeaker(_ speaker: String) {
        guestSpeakers.removeAll { $0.name == speaker }
    }
}

#Preview {
    NewEventView1(isNewEventViewPresented: .constant(false))
}
