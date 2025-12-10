//
//  EventPriceView.swift
//  Vibesy
//
//  Created by Alexander Cleoni on 3/6/25.
//

import SwiftUI

struct EventPriceView: View {
    let event: Event
    @Binding var showWebView: Bool
    @Binding var eventIsReserved: Bool
    @State private var selectedExternalURL: URL?
    
    var body: some View {
        VStack(spacing: 8) {
            Text("Event Price")
                .font(.aBeeZeeRegular(size: 16))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding([.top, .horizontal])
            
            if event.isFreeEvent {
                freeEventView
            } else if event.hasExternalTicketLinks {
                externalTicketsView
            } else if event.hasInternalPricing {
                internalPricingView
            } else {
                fallbackView
            }
        }
        .sheet(isPresented: $showWebView) {
            if let url = selectedExternalURL {
                WebView(url: url)
            } else if let firstLink = event.firstExternalLink,
                let url = URL(string: firstLink)
            {
                WebView(url: url)
            }
        }
    }
    
    // MARK: - Subviews
    
    private var freeEventView: some View {
        HStack(alignment: .center) {
            Image(systemName: "gift.fill")
                .foregroundColor(.goldenBrown)
            Text("Free Event")
                .font(.aBeeZeeRegular(size: 16))
                .foregroundColor(.goldenBrown)
            Spacer()
        }
        .padding(.horizontal)
    }
    
    private var externalTicketsView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(
                    event.priceDetails.filter { $0.hasValidLink },
                    id: \.self
                ) { price in
                    Button(action: {
                        if let urlString = price.link,
                            let url = URL(string: urlString)
                        {
                            selectedExternalURL = url
                            showWebView = true
                        }
                    }) {
                        VStack(alignment: .center, spacing: 8) {
                            HStack {
                                Image(systemName: "link")
                                    .foregroundColor(.blue)
                                Text("View Tickets Online")
                                    .font(.aBeeZeeRegular(size: 14))
                                    .foregroundStyle(.blue)
                            }
                            .underline()
                            
                            if !price.title.isEmpty {
                                Text(price.title)
                                    .font(.aBeeZeeRegular(size: 12))
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.vertical, 8)
                        .padding(.horizontal, 12)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(8)
                    }
                }
            }
            .padding(.horizontal)
        }
    }
    
    private var internalPricingView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(event.priceDetails, id: \.self) { price in
                    VStack(alignment: .center, spacing: 8) {
                        HStack {
                            Image(systemName: "creditcard.fill")
                                .foregroundColor(.goldenBrown)
                            VStack(alignment: .leading) {
                                Text(price.title)
                                    .font(.aBeeZeeRegular(size: 14))
                                    .fontWeight(.medium)
                                Text(price.formattedPrice)
                                    .font(.aBeeZeeRegular(size: 14))
                                    .foregroundStyle(.goldenBrown)
                            }
                        }
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal, 12)
                    .background(Color.goldenBrown.opacity(0.1))
                    .cornerRadius(8)
                }
            }
            .padding(.horizontal)
        }
    }
    
    private var fallbackView: some View {
        Text("Event Details Available")
            .font(.aBeeZeeRegular(size: 14))
            .foregroundColor(.secondary)
            .padding(.horizontal)
    }
}
