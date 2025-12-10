//
//  EventScreenHeaderView.swift
//  Vibesy
//
//  Created by Alexander Cleoni on 3/6/25.
//

import SwiftUI

struct EventScreenHeaderView: View {
    @EnvironmentObject var eventModel: EventModel
    @EnvironmentObject var interactionModel: InteractionModel
    @EnvironmentObject var authenticationModel: AuthenticationModel
    
    @State var showFlagContentView = false
    @State private var showPaidEventDeletionAlert: Bool = false
    
    @Binding var isNewEventViewPresented: Bool
    
    let enableAdminMode: Bool
    let systemImageName: String?
    let navigate: ((_ direction: Direction) -> Void)?
    
    var body: some View {
        HStack {
            BackButtonView(systemImageName: systemImageName, rounded: false) {
                eventModel.clearCurrentEventDetails()
                if let navigate {
                    navigate(.back)
                }
            }
            Spacer()
            if enableAdminMode {
                adminMenu
            } else {
                userMenu
            }
        }
        .sheet(isPresented: $showFlagContentView) {
            FlagContentView(showFlagContentView: $showFlagContentView) {
                handleFlagContent()
            }
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
            .presentationCornerRadius(24)
            .interactiveDismissDisabled(false)
        }
        .alert("Paid Event Deletion", isPresented: $showPaidEventDeletionAlert) {
            Button("Email Support") {
                openPaidEventDeletionEmail()
            }
            Button("Cancel", role: .cancel) {
                showPaidEventDeletionAlert = false
            }
        } message: {
            Text(
                "Charged events cannot be deleted from the app. Please contact the system administrator at foundavibellc@gmail.com."
            )
        }
        .padding()
    }
    
    // MARK: - Subviews
    
    private var adminMenu: some View {
        Menu {
            Button("Edit") {
                isNewEventViewPresented.toggle()
            }
            Button("Delete") {
                handleDeleteEvent()
            }
        } label: {
            Image(systemName: "ellipsis")
        }
        .padding()
    }
    
    private var userMenu: some View {
        Menu {
            Button(action: { showFlagContentView.toggle() }) {
                Label("Report Content", systemImage: "flag")
            }
        } label: {
            Label("", systemImage: "ellipsis.circle")
        }
        .foregroundStyle(.espresso)
    }
    
    // MARK: - Helper Methods
    
    private func handleDeleteEvent() {
        guard let currentEvent = eventModel.currentEventDetails else {
            print("DELETE BUTTON: No current event found in eventModel.currentEventDetails")
            return
        }
        
        print("DELETE BUTTON: Event found - \(currentEvent.title)")
        print("Price details count: \(currentEvent.priceDetails.count)")
        print("Is user generated: \(currentEvent.isUserGenerated)")
        print("Has internal pricing: \(currentEvent.hasInternalPricing)")
        print("Is free event: \(currentEvent.isFreeEvent)")
        print("Has external links: \(currentEvent.hasExternalTicketLinks)")
        
        for (index, priceDetail) in currentEvent.priceDetails.enumerated() {
            print("Price \(index): \(priceDetail.title) - \(priceDetail.formattedPrice)")
        }
        
        if currentEvent.hasInternalPricing {
            print("PAID EVENT: Showing deletion prevention alert")
            showPaidEventDeletionAlert = true
        } else {
            print("FREE EVENT: Allowing deletion")
            Task {
                do {
                    try await eventModel.deleteCurrentEvent()
                    eventModel.clearCurrentEventDetails()
                } catch {
                    print("Failed to delete event: \(error.localizedDescription)")
                }
            }
        }
    }
    
    private func handleFlagContent() {
        guard let user = authenticationModel.state.currentUser,
              let currentEventDetails = eventModel.currentEventDetails
        else { return }
        
        Task {
            do {
                interactionModel.unlikeEvent(
                    userId: user.id,
                    eventId: currentEventDetails.id.uuidString
                )
                interactionModel.dislikeEvent(
                    userId: user.id,
                    eventId: currentEventDetails.id.uuidString
                )
                let event = eventModel.events.first(where: {
                    $0.id.uuidString == currentEventDetails.id.uuidString
                })
                if let event {
                    // Check if this is a paid event before allowing deletion
                    if !event.hasInternalPricing {
                        try await eventModel.deleteEvent(event)
                    } else {
                        print("Attempted to delete paid event via flag content - deletion blocked")
                    }
                }
                await MainActor.run {
                    eventModel.clearCurrentEventDetails()
                }
            } catch {
                await MainActor.run {
                    eventModel.clearCurrentEventDetails()
                }
            }
        }
    }
    
    private func openPaidEventDeletionEmail() {
        guard let currentEvent = eventModel.currentEventDetails,
              let url = URL(
                string:
                    "mailto:foundavibellc@gmail.com?subject=Event%20Deletion%20Request&body=Hello,%0D%0A%0D%0AI%20would%20like%20to%20request%20the%20deletion%20of%20my%20paid%20event:%20\(currentEvent.title.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? currentEvent.title)%0D%0A%0D%0AEvent%20ID:%20\(currentEvent.id.uuidString)%0D%0A%0D%0APlease%20let%20me%20know%20the%20next%20steps%20for%20handling%20any%20existing%20reservations%20and%20refunds.%0D%0A%0D%0AThank%20you!"
              )
        else { return }
        
        UIApplication.shared.open(url)
    }
}
