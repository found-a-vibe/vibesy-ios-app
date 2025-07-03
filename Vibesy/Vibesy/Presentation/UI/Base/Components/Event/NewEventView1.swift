//
//  NewEvent.swift
//  FoundAVibe
//
//  Created by Alexander Cleoni on 11/22/24.
//

import SwiftUI
import PhotosUI

struct NewEventView1: View {
    @SwiftUI.Environment(\.dismiss) var dismiss
    @EnvironmentObject var eventModel: EventModel
    
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
                    // Post event logic here
                    if eventImages.count < 1 {
                        alertMessage = ("Event Image Required!", "Please upload at least one image of your event.")
                        showAlert.toggle()
                    } else {
                        eventImages.forEach { image in
                            eventModel.newEvent?.newImages?.append(image)
                        }
                        guestSpeakers.forEach { speaker in
                            eventModel.newEvent?.guests.append(speaker)
                        }
                        prices.forEach { price in
                            eventModel.newEvent?.priceDetails.append(price)
                        }
                        isNewEventViewPresented = false
                        eventModel.addEvent()
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
                Button(action: addPrice) {
                    Image(systemName: "plus.circle.fill")
                        .foregroundColor(.sandstone)
                }
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(prices, id: \.title) { price in
                        
                        HStack {
                            Text("\(price.title)\n$\(price.price)")
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
                .onTapGesture {
                    if (speakerName.isEmpty) {
                        alertMessage = ("Speaker Name Required!", "Please enter a name for the gueest speaker.")
                        showAlert.toggle()
                    }
                }
                .onChange(of: selectedGuestImages) { _, _ in
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
                    ForEach(guestSpeakers, id: \.self) { speaker in
                        VStack(alignment: .center) {
                            Image(uiImage: speaker.image!)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 100, height: 100)
                                .clipped()
                                .cornerRadius(8)
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
            .animation(.easeInOut)
    }
    
    private func loadImages(from items: [PhotosPickerItem]) async -> [UIImage] {
        await withTaskGroup(of: UIImage?.self) { group in
            for item in items {
                group.addTask {
                    if let data = try? await item.loadTransferable(type: Data.self),
                       let uiImage = UIImage(data: data) {
                        return uiImage
                    }
                    return nil
                }
            }
            var results: [UIImage] = []
            for await image in group.compactMap({ $0 }) {
                results.append(image)
            }
            return results
        }
    }
    
    // MARK: - Helper Functions
    private func addPrice() {
        guard !priceTitle.isEmpty, !eventPrice.isEmpty else { return }
        prices.append(PriceDetails(title: priceTitle, price: eventPrice, link: ""))
        priceTitle = ""
        eventPrice = ""
    }
    
    private func removePrice(_ price: PriceDetails) {
        prices.removeAll { $0.title == price.title && $0.price == price.price }
    }
    
    private func addSpeaker(image: UIImage) {
        guard !speakerName.isEmpty else { return }
        guestSpeakers.append(Guest(id: UUID(), name: speakerName, role: speakerRole, image: image, imageUrl: nil))
        speakerName = ""
        speakerRole = ""
    }
    
    private func removeSpeaker(_ speaker: String) {
        guestSpeakers.removeAll { $0.name == speaker }
    }
}

#Preview {
    NewEventView1(isNewEventViewPresented: .constant(false))
}
