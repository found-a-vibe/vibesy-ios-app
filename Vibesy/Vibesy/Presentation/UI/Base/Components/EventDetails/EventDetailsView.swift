//
//  EventDetailsView.swift
//  Vibesy
//
//  Created by Alexander Cleoni on 3/6/25.
//

import Kingfisher
import SwiftUI

struct EventScreenView: View {
    @SwiftUI.Environment(\.dismiss) var dismiss
    
    @EnvironmentObject var eventModel: EventModel
    @EnvironmentObject var userProfileModel: UserProfileModel
    @EnvironmentObject var interactionModel: InteractionModel
    @EnvironmentObject var authenticationModel: AuthenticationModel
    @StateObject private var userOrdersService = UserOrdersService.shared
    
    @State private var isNewEventViewPresented: Bool = false
    
    @State var event: Event = Event.empty()
    
    @State private var eventIsLiked: Bool = false
    @State private var eventIsReserved: Bool = false
    
    @State var goNext: Bool = false
    
    var handleNavigation = false
    
    var enableAdminMode: Bool = false
    var navigationSource: EventStatus? = nil
    
    var systemImageName: String? = nil
    
    @State var showReservationConfirmation: Bool = false
    @State var showReservationCancellation: Bool = false
    @State var showReservationSheet: Bool = false
    @State private var showTicketListView: Bool = false
    @State private var showPaidEventCancellationAlert: Bool = false
    @State private var showReservationsView: Bool = false
    
    @State private var showWebView = false
    @State private var reservedUserProfiles: [UserProfile] = []
    
    var navigate: ((_ direction: Direction) -> Void)? = nil
    
    // Computed property to check if current user is the event creator
    var isCurrentUserEventCreator: Bool {
        guard let currentUserId = authenticationModel.state.currentUser?.id else { return false }
        return event.isCreatedBy(currentUserId)
    }
    
    // Computed property to check if user has purchased tickets for this paid event
    var hasPurchasedTickets: Bool {
        guard let currentUserId = authenticationModel.state.currentUser?.id else { return false }
        return event.hasInternalPricing && 
               eventIsReserved && 
               userOrdersService.hasPurchasedTickets(for: event.id.uuidString, userId: currentUserId)
    }
    
    // Get the order ID for ticket viewing
    var orderIdForTickets: Int? {
        guard let currentUserId = authenticationModel.state.currentUser?.id else { return nil }
        return userOrdersService.getOrderId(for: event.id.uuidString, userId: currentUserId)
    }
    
    // Computed property to check if there's a bottom button showing
    var hasBottomButton: Bool {
        return (eventIsLiked && !enableAdminMode && !isCurrentUserEventCreator && !eventIsReserved) ||
               (eventIsReserved && !isCurrentUserEventCreator)
    }
    
    func checkLikedEvents() {
        let likedEvents = Array(eventModel.currentEventDetails?.likes ?? [])
        let uid = authenticationModel.state.currentUser?.id
        
        if let uid {
            let found = likedEvents.first (where: { $0 == uid})
            if found != nil {
                eventIsLiked = true
            }
        }
    }
    
    func checkedReservedEvents() {
        let reservedEvents = Array(eventModel.currentEventDetails?.reservations ?? [])
        let uid = authenticationModel.state.currentUser?.id
        
        if let uid {
            let found = reservedEvents.first (where: { $0 == uid})
            if found != nil {
                eventIsReserved = true
            }
        }
    }
    
    func interactWithEvent() {
        if (eventIsLiked) {
            eventModel.buttonSwipeAction = nil
            if let uid = authenticationModel.state.currentUser?.id {
                interactionModel.unlikeEvent(userId: uid, eventId: event.id.uuidString) {
                    eventModel.removeLikedEvent(event)
                    if let navigate {
                        navigate(.back)
                    }
                }
                
            }
        } else {
            eventModel.buttonSwipeAction = .like
        }
    }
    
    func reserveEvent() {
        if let uid = authenticationModel.state.currentUser?.id {
            interactionModel.reserveEvent(userId: uid, eventId: event.id.uuidString)
        }
    }
    
    func cancelEventReservation() {
        if let uid = authenticationModel.state.currentUser?.id {
            interactionModel.cancelEventReservation(userId: uid, eventId: event.id.uuidString) {
                if let navigate {
                    navigate(.back)
                }
            }
            
        }
    }
    
    func loadReservedUserProfiles() {
        guard let userId = authenticationModel.state.currentUser?.id else { return }
        let reservedUserIds = event.reservations
        
        if !reservedUserIds.isEmpty {
            // Clear existing profiles first
            reservedUserProfiles = []
            
            // Fetch profiles asynchronously - they will be updated via onReceive
            userProfileModel.getMatchedUsersProfiles(userId: userId, userIds: reservedUserIds)
        } else {
            reservedUserProfiles = []
        }
    }
    
    var image: String {
        if event.images.count > 0 {
            return event.images[0]
        }
        return "https://upload.wikimedia.org/wikipedia/commons/1/14/No_Image_Available.jpg"
    }
    
    var body: some View {
        VStack {
            // Header Section
            HeaderView(isNewEventViewPresented: $isNewEventViewPresented, enableAdminMode: enableAdminMode, systemImageName: systemImageName) { direction in
                if let navigate {
                    navigate(direction)
                }
            }
            ZStack {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 16) {
                        // Event Image
                        EventImageView(title: event.title, eventImage: image, eventIsLiked: eventIsLiked, eventIsReserved: eventIsReserved, enableAdminMode: enableAdminMode, isUserGenerated: event.isUserGenerated, interactWithEvent: interactWithEvent)
                        // Event Details
                        EventDetailsView(description: event.description, location: event.location, date: event.date, timeRange: event.timeRange, likesCount: event.likeCount, reservationsCount: event.reservationCount)
                        // Tags
                        TagsView(tags: event.hashtags)
                        // Speaker/Guest Section
                        if event.guests.count > 0 {
                            SpeakerGuestView(guests: event.guests)
                        }
                        
                        PriceDetailsView(event: event, showWebView: $showWebView, eventIsReserved: $eventIsReserved)
                        
                        // Footer Section
                        LikedUsersView(users: $userProfileModel.matchedProfiles) { direction in
                            if let navigate {
                                goNext = true
                                navigate(direction)
                            }
                        }
                        
                        // Add spacing for bottom button
                        Spacer(minLength: hasBottomButton ? 80 : 20)
                    }
                    .overlay(alignment: .center) {
                        if showReservationConfirmation || showReservationCancellation {
                            RoundedRectangle(cornerRadius: 20)
                                .fill(
                                    LinearGradient(
                                        gradient: Gradient(colors: [
                                            .goldenBrown,
                                            .espresso,
                                        ]), startPoint: .topLeading, endPoint: .bottomTrailing
                                    )
                                )
                                .frame(maxWidth: 393, maxHeight: 155)
                                .padding()
                                .overlay {
                                    ZStack {
                                        
                                        VStack(alignment: .center, spacing: 12) {
                                            if showReservationConfirmation {
                                                Text("Get Ready to Vibe!")
                                                    .font(.abeezeeItalic(size: 20))
                                                    .multilineTextAlignment(.center)
                                                Text("Your RSVP is confirmed.\nYou can manage your reservation from your profile.")
                                                    .font(.abeezeeItalic(size: 16))
                                                    .multilineTextAlignment(.center)
                                                    .padding(.horizontal)
                                                
                                            }
                                            if showReservationCancellation {
                                                Text("Are You Sure?")
                                                    .font(.abeezeeItalic(size: 20))
                                                
                                                Text("If you bought your tickets online, please request a refund directly from the original ticket provider.")
                                                    .font(.abeezeeItalic(size: 14))
                                                    .multilineTextAlignment(.center)
                                                    .padding(.horizontal)
                                            }
                                            Button(action: {
                                                if showReservationConfirmation {
                                                    showReservationConfirmation.toggle()
                                                    interactWithEvent()
                                                }
                                                if showReservationCancellation {
                                                    showReservationCancellation.toggle()
                                                    cancelEventReservation()
                                                }
                                            }) {
                                                Text(showReservationConfirmation ? "Confirm" : "Cancel")
                                                    .font(.abeezeeItalic(size: 12))
                                                    .foregroundColor(.white)
                                                    .frame(width: 124, height: 28)
                                                    .padding(2)
                                                    .background(.sandstone)
                                                    .cornerRadius(8)
                                            }
                                        }
                                    }
                                    .foregroundStyle(.white)
                                }
                                .animation(.easeInOut)
                        }
                    }
                    .sheet(isPresented: $showReservationSheet) {
                        ReservationSheet(
                            event: event,
                            onReservationSuccess: {
                                // Call the existing reserveEvent function
                                reserveEvent()
                                // Update local state to show the event is now reserved
                                eventIsReserved = true
                                // Don't auto-dismiss the sheet - let user manually dismiss after viewing payment success
                                // showReservationSheet = false
                            }
                        )
                        .environmentObject(authenticationModel)
                    }
                    .sheet(isPresented: $showTicketListView) {
                        if let orderId = orderIdForTickets {
                            TicketListView(orderId: orderId)
                        } else {
                            Text("Unable to load tickets")
                                .padding()
                        }
                    }
                    .sheet(isPresented: $showReservationsView) {
                        EventReservationsView(
                            event: event,
                            reservedUserProfiles: reservedUserProfiles
                        )
                    }
                }
                .padding()
            }
            
            VStack(alignment: .center) {
                // Show Reserve button for non-creators
                if eventIsLiked && !enableAdminMode && !isCurrentUserEventCreator && !eventIsReserved {
                    Button(action: {
                        showReservationSheet = true
                    }) {
                        Text("Reserve")
                            .font(.abeezeeItalic(size: 12))
                            .foregroundColor(.white)
                            .frame(width: 124, height: 28)
                            .padding(2)
                            .background(.espresso)
                            .cornerRadius(8)
                    }
                }
                
                // Show View Reservations button for event creators (only from posted events tab)
                if isCurrentUserEventCreator && navigationSource == .postedEvents {
                    Button(action: {
                        // Reset and load fresh profile data
                        userProfileModel.resetMatchedUsersProfiles()
                        loadReservedUserProfiles()
                        showReservationsView = true
                    }) {
                        Text("View Guest List")
                            .font(.abeezeeItalic(size: 12))
                            .foregroundColor(.white)
                            .frame(width: 150, height: 28)
                            .padding(2)
                            .background(.espresso)
                            .cornerRadius(8)
                    }
                }
                
                if eventIsReserved && !isCurrentUserEventCreator {
                    // Show buttons horizontally
                    HStack(spacing: 16) {
                        // Show View Tickets button for paid events with purchased tickets
                        if hasPurchasedTickets {
                            Button(action: {
                                showTicketListView = true
                            }) {
                                Text("View Ticket(s)")
                                    .font(.abeezeeItalic(size: 12))
                                    .foregroundColor(.white)
                                    .frame(width: 124, height: 28)
                                    .padding(2)
                                    .background(.sandstone)
                                    .cornerRadius(8)
                            }
                        }
                        
                        Button(action: {
                            // Check if this is a paid event that the user has purchased
                            if hasPurchasedTickets {
                                showPaidEventCancellationAlert = true
                            } else {
                                showReservationCancellation.toggle()
                            }
                        }) {
                            Text("Cancel Reservation")
                                .font(.abeezeeItalic(size: 12))
                                .foregroundColor(.white)
                                .frame(width: 124, height: 28)
                                .padding(2)
                                .background(.espresso)
                                .cornerRadius(8)
                        }
                    }
                }
            }
            .padding()
            
        }
        
        .navigationDestination(isPresented: handleNavigation ? $goNext : .constant(false)) {
            MatchedUserDetailsView()
                .navigationBarBackButtonHidden()
        }
        .fullScreenCover(isPresented: $isNewEventViewPresented) {
            NavigationStack {
                NewEventView0(isNewEventViewPresented: $isNewEventViewPresented)
            }
        }
        .alert("Paid Event Cancellation", isPresented: $showPaidEventCancellationAlert) {
            Button("Email Support") {
                if let url = URL(string: "mailto:foundavibellc@gmail.com?subject=Ticket%20Refund%20Request&body=Hello,%0D%0A%0D%0AI%20would%20like%20to%20request%20a%20refund%20for%20my%20ticket%20purchase%20for%20the%20event:%20\(event.title.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? event.title)%0D%0A%0D%0APlease%20let%20me%20know%20the%20next%20steps.%0D%0A%0D%0AThank%20you!") {
                    UIApplication.shared.open(url)
                }
            }
            Button("Cancel", role: .cancel) {
                showPaidEventCancellationAlert = false
            }
        } message: {
            Text("To cancel your paid reservation and request a refund, please contact our customer support team at foundavibellc@gmail.com. We'll help you process your refund request.")
        }
        .background(Color.white)
        .onAppear {
            if let userId = authenticationModel.state.currentUser?.id, let details = eventModel.currentEventDetails {
                event = details
                
                // Debug event details
                print("📱 EventDetailsView loaded for event: \(event.title)")
                print("👥 Event has \(event.guests.count) guests:")
                for guest in event.guests {
                    print("  - \(guest.name) (\(guest.role)): ImageURL = \(guest.imageUrl?.isEmpty == false ? guest.imageUrl! : "[EMPTY or NIL]")")
                }
                
                userProfileModel.getMatchedUsersProfiles(userId: userId,userIds: event.likes.filter { $0 != userId})
                
                // Preload guest images to warm cache
                preloadGuestImages(for: event)
            }
            checkLikedEvents()
            checkedReservedEvents()
        }
        .onChange(of: eventModel.events) { _, updatedEvents in
            guard let _ = updatedEvents.firstIndex(where: { $0.id.uuidString == event.id.uuidString }) else {
                if let navigate {
                    navigate(.back)
                }
                return
            }
            
        }
        .onReceive(userProfileModel.$matchedProfiles) { profiles in
            // Keep local copy in sync for the reservations sheet
            reservedUserProfiles = profiles
            
            // Preload matched profile images to warm cache
            preloadMatchedProfileImages(profiles: profiles)
        }
        .onDisappear {
            userProfileModel.resetMatchedUsersProfiles()
        }
    }
    
    // MARK: - Image Preloading Functions
    
    /// Preloads guest images to warm the cache for faster display
    private func preloadGuestImages(for event: Event) {
        guard !event.guests.isEmpty else { return }
        
        // Collect valid URLs
        let guestImageUrls = event.guests.compactMap { guest -> URL? in
            guard let imageUrlString = guest.imageUrl, 
                  !imageUrlString.isEmpty,
                  let imageUrl = URL(string: imageUrlString) else {
                print("⚠️ Skipping guest \(guest.name) - no valid image URL")
                return nil
            }
            return imageUrl
        }
        
        guard !guestImageUrls.isEmpty else { return }
        
        print("🔄 Batch preloading \(guestImageUrls.count) guest images...")
        
        // Use ImagePrefetcher for efficient batch loading
        let prefetcher = ImagePrefetcher(urls: guestImageUrls) { skippedResources, failedResources, completedResources in
            print("✅ Guest image preloading completed:")
            print("  - Completed: \(completedResources.count)")
            print("  - Failed: \(failedResources.count)")
            print("  - Skipped: \(skippedResources.count)")
        }
        
        // Start prefetching with higher priority
        prefetcher.start()
    }
    
    /// Preloads matched profile images to warm the cache for faster display
    private func preloadMatchedProfileImages(profiles: [UserProfile]) {
        guard !profiles.isEmpty else { return }
        
        // Collect valid profile image URLs
        let profileImageUrls = profiles.compactMap { profile -> URL? in
            guard !profile.profileImageUrl.isEmpty,
                  let imageUrl = URL(string: profile.profileImageUrl) else {
                print("⚠️ Skipping profile \(profile.fullName) - no valid image URL")
                return nil
            }
            return imageUrl
        }
        
        guard !profileImageUrls.isEmpty else { return }
        
        print("🔄 Batch preloading \(profileImageUrls.count) matched profile images...")
        
        // Use ImagePrefetcher for efficient batch loading
        let prefetcher = ImagePrefetcher(urls: profileImageUrls) { skippedResources, failedResources, completedResources in
            print("✅ Profile image preloading completed:")
            print("  - Completed: \(completedResources.count)")
            print("  - Failed: \(failedResources.count)")
            print("  - Skipped: \(skippedResources.count)")
        }
        
        // Start prefetching
        prefetcher.start()
    }
}




// MARK: - Header View
struct HeaderView: View {
    @EnvironmentObject var eventModel: EventModel
    @EnvironmentObject var interactionModel: InteractionModel
    @EnvironmentObject var authenticationModel: AuthenticationModel
    
    @State var showFlagContentView = false
    @State private var showPaidEventDeletionAlert: Bool = false
    
    @Binding var isNewEventViewPresented: Bool
    
    var enableAdminMode: Bool = false
    
    var systemImageName: String? = nil
    
    var navigate: ((_ direction: Direction) -> Void)? = nil
    
    var body: some View {
        HStack {
            BackButtonView(systemImageName: systemImageName) {
                eventModel.clearCurrentEventDetails()
                if let navigate {
                    navigate(.back)
                }
            }
            Spacer()
            Text("Event")
                .foregroundStyle(.espresso)
                .font(.abeezeeItalic(size: 26))
            Spacer()
            if enableAdminMode {
                Menu {
                    Button("Edit", action: {
                        isNewEventViewPresented.toggle()
                    })
                    Button("Delete", action: {
                        // Check if this is a paid event
                        if let currentEvent = eventModel.currentEventDetails {
                            print("🗑️ DELETE BUTTON: Event found - \(currentEvent.title)")
                            print("💵 Price details count: \(currentEvent.priceDetails.count)")
                            print("🏭 Is user generated: \(currentEvent.isUserGenerated)")
                            print("🔄 Has internal pricing: \(currentEvent.hasInternalPricing)")
                            print("🆓 Is free event: \(currentEvent.isFreeEvent)")
                            print("🔗 Has external links: \(currentEvent.hasExternalTicketLinks)")
                            
                            for (index, priceDetail) in currentEvent.priceDetails.enumerated() {
                                print("🏷️ Price \(index): \(priceDetail.title) - \(priceDetail.formattedPrice)")
                            }
                            
                            if currentEvent.hasInternalPricing {
                                print("⚠️ PAID EVENT: Showing deletion prevention alert")
                                // Show alert for paid events
                                showPaidEventDeletionAlert = true
                            } else {
                                print("✅ FREE EVENT: Allowing deletion")
                                // Allow deletion for free events
                                Task {
                                    do {
                                        try await eventModel.deleteCurrentEvent()
                                        eventModel.clearCurrentEventDetails()
                                    } catch {
                                        print("Failed to delete event: \(error.localizedDescription)")
                                    }
                                }
                            }
                        } else {
                            print("❌ DELETE BUTTON: No current event found in eventModel.currentEventDetails")
                        }
                    })
                } label: {
                    Image(systemName: "ellipsis")
                }
                .padding()
            }
            if !enableAdminMode {
                Menu {
                    Button(action: { showFlagContentView.toggle() }) {
                        Label("Report Content", systemImage: "flag")
                    }
                } label: {
                    Label("", systemImage: "ellipsis.circle")
                }
                .foregroundStyle(.espresso)
            }
        }
        .sheet(isPresented: $showFlagContentView) {
            FlagContentView(showFlagContentView: $showFlagContentView) {
                if let user = authenticationModel.state.currentUser, let currentEventDetails = eventModel.currentEventDetails {
                    Task {
                        do {
                            interactionModel.unlikeEvent(userId: user.id, eventId: currentEventDetails.id.uuidString)
                            interactionModel.dislikeEvent(userId: user.id, eventId: currentEventDetails.id.uuidString)
                            let event = eventModel.events.first(where: { $0.id.uuidString == currentEventDetails.id.uuidString })
                            if let event {
                                // Check if this is a paid event before allowing deletion
                                if !event.hasInternalPricing {
                                    try await eventModel.deleteEvent(event)
                                } else {
                                    print("⚠️ Attempted to delete paid event via flag content - deletion blocked")
                                    // For paid events, we'll just mark it as flagged but not delete
                                }
                            }
                            await MainActor.run {
                                eventModel.clearCurrentEventDetails()
                            }
                        } catch {
                            // TODO: Consider surfacing this error to the user or logging.
                            await MainActor.run {
                                eventModel.clearCurrentEventDetails()
                            }
                        }
                    }
                }
            }
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
            .presentationCornerRadius(24)
            .interactiveDismissDisabled(false)
        }
        .alert("Paid Event Deletion", isPresented: $showPaidEventDeletionAlert) {
            Button("Email Support") {
                if let currentEvent = eventModel.currentEventDetails,
                   let url = URL(string: "mailto:foundavibellc@gmail.com?subject=Event%20Deletion%20Request&body=Hello,%0D%0A%0D%0AI%20would%20like%20to%20request%20the%20deletion%20of%20my%20paid%20event:%20\(currentEvent.title.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? currentEvent.title)%0D%0A%0D%0AEvent%20ID:%20\(currentEvent.id.uuidString)%0D%0A%0D%0APlease%20let%20me%20know%20the%20next%20steps%20for%20handling%20any%20existing%20reservations%20and%20refunds.%0D%0A%0D%0AThank%20you!") {
                    UIApplication.shared.open(url)
                }
            }
            Button("Cancel", role: .cancel) {
                showPaidEventDeletionAlert = false
            }
        } message: {
            Text("Charged events cannot be deleted from the app. Please contact the system administrator at foundavibellc@gmail.com.")
        }
        .padding(.horizontal)
    }
}

// MARK: - Event Image View
struct EventImageView: View {
    @EnvironmentObject var eventModel: EventModel
    
    var title: String
    var eventImage: String?
    
    var eventIsLiked: Bool
    var eventIsReserved: Bool
    
    var enableAdminMode: Bool
    var isUserGenerated: Bool = true // Default to user generated for backward compatibility
    
    var interactWithEvent: (() -> Void)
    
    var body: some View {
        ZStack(alignment: .bottomLeading) {
            KFImage(URL(string: eventImage ?? ""))
                .resizable()
                .aspectRatio(contentMode: isUserGenerated ? .fill : .fit)
                .frame(height: 200)
                .cornerRadius(12)
                .clipped()
            
            Text(title)
                .font(.abeezeeItalic(size: 16))
                .bold()
                .foregroundColor(.sandstone)
                .padding(8)
                .background(Color.white.opacity(0.7))
                .cornerRadius(8)
                .padding(.leading, 16)
                .padding(.bottom, 12)
        }
        .overlay(alignment: .topTrailing) {
            if !enableAdminMode && !eventIsReserved {
                Image(systemName: eventIsLiked ? "heart.fill" : "heart")
                    .foregroundColor(.red)
                    .padding()
                    .onTapGesture {
                        interactWithEvent()
                    }
            }
        }
    }
}

// MARK: - Event Details View
struct EventDetailsView: View {
    var description: String
    var location: String
    var date: String
    var timeRange: String
    var likesCount: Int = 0
    var reservationsCount: Int = 0
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Likes and Reservations Count Row
            HStack(spacing: 16) {
                HStack {
                    Image(systemName: "heart.fill")
                        .foregroundColor(.red)
                    Text("\(likesCount) \(likesCount == 1 ? "Like" : "Likes")")
                        .font(.abeezeeItalic(size: 14))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                HStack {
                    Image(systemName: "person.2.fill")
                        .foregroundColor(.sandstone)
                    Text("\(reservationsCount) \(reservationsCount == 1 ? "Reservation" : "Reservations")")
                        .font(.abeezeeItalic(size: 14))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .trailing)
            }
            
            // Date and Location Row
            HStack(spacing: 16) {
                HStack {
                    Image(systemName: "calendar")
                    VStack(alignment: .leading) {
                        Text("\(date)")
                            .font(.abeezeeItalic(size: 16))
                        Text("\(timeRange)")
                            .font(.abeezeeItalic(size: 12))
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                HStack {
                    Image("Location")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 24, height: 24)
                    Text(location)
                        .font(.abeezeeItalic(size: 16))
                }
                .frame(maxWidth: .infinity, alignment: .trailing)
            }
            VStack(alignment: .leading) {
                Text("Event Details")
                    .font(.abeezeeItalic(size: 16))
                    .padding(.top, 8)
                
                Text(description)
                    .font(.abeezeeItalic(size: 12))
                    .foregroundColor(.gray)
            }
        }
        .padding([.top, .horizontal])
    }
}

// MARK: - Tags View
struct TagsView: View {
    var tags: [String]
    var body: some View {
        HStack {
            ForEach(tags, id: \.self) { tag in
                Text(tag)
                    .font(.caption)
                    .foregroundColor(.white)
                    .padding(6)
                    .background(.sandstone)
                    .cornerRadius(8)
            }
        }
        .padding(.horizontal)
    }
}

// MARK: - Speaker/Guest Section
struct SpeakerGuestView: View {
    let guests: [Guest]
    
    var body: some View {
        VStack(alignment: .center) {
            Text("Speaker/Guest")
                .font(.abeezeeItalic(size: 16))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding([.top, .horizontal])
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(guests, id: \.self) { guest in
                        GuestCardView(
                            name: guest.name, 
                            imageName: guest.imageUrl ?? "",
                            role: guest.role
                        )
                    }
                }
                .padding(.horizontal)
            }
        }
    }
}

struct PriceDetailsView: View {
    let event: Event
    @Binding var showWebView: Bool
    @Binding var eventIsReserved: Bool
    @State private var selectedExternalURL: URL?
    
    var body: some View {
        VStack {
            Text("Event Price")
                .font(.abeezeeItalic(size: 16))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding([.top, .horizontal])
            
            if event.isFreeEvent {
                // User-generated event with no price details = Free
                HStack {
                    Image(systemName: "gift.fill")
                        .foregroundColor(.green)
                    Text("Free Event")
                        .font(.abeezeeItalic(size: 16))
                        .foregroundColor(.green)
                }
                .padding(.bottom)
                
            } else if event.hasExternalTicketLinks {
                // System-generated event with external links
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(event.priceDetails.filter { $0.hasValidLink }, id: \.self) { price in
                            Button(action: {
                                if let urlString = price.link, let url = URL(string: urlString) {
                                    selectedExternalURL = url
                                    showWebView = true
                                }
                            }) {
                                VStack(alignment: .center, spacing: 8) {
                                    HStack {
                                        Image(systemName: "link")
                                            .foregroundColor(.blue)
                                        Text("View Tickets Online")
                                            .font(.abeezeeItalic(size: 14))
                                            .foregroundStyle(.blue)
                                    }
                                    .underline()
                                    
                                    if !price.title.isEmpty {
                                        Text(price.title)
                                            .font(.abeezeeItalic(size: 12))
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
                
            } else if event.hasInternalPricing {
                // User-generated event with Stripe pricing
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(event.priceDetails, id: \.self) { price in
                            VStack(alignment: .center, spacing: 8) {
                                HStack {
                                    Image(systemName: "creditcard.fill")
                                        .foregroundColor(.green)
                                    VStack(alignment: .leading) {
                                        Text(price.title)
                                            .font(.abeezeeItalic(size: 14))
                                            .fontWeight(.medium)
                                        Text(price.formattedPrice)
                                            .font(.abeezeeItalic(size: 14))
                                            .foregroundStyle(.green)
                                    }
                                }
                            }
                            .padding(.vertical, 8)
                            .padding(.horizontal, 12)
                            .background(Color.green.opacity(0.1))
                            .cornerRadius(8)
                        }
                    }
                    .padding(.horizontal)
                }
                
            } else {
                // Fallback for edge cases
                Text("Event Details Available")
                    .font(.abeezeeItalic(size: 14))
                    .foregroundColor(.secondary)
                    .padding(.horizontal)
            }
        }
        .sheet(isPresented: $showWebView) {
            if let url = selectedExternalURL {
                WebView(url: url)
            } else if let firstLink = event.firstExternalLink, let url = URL(string: firstLink) {
                WebView(url: url)
            }
        }
    }
}

struct GuestCardView: View {
    var name: String
    var imageName: String
    var role: String = "Speaker"
    
    var body: some View {
        VStack(spacing: 8) {
            KFImage(URL(string: imageName))
                .placeholder {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 93, height: 97)
                        .overlay {
                            Image(systemName: "person.fill")
                                .foregroundColor(.gray)
                                .font(.title2)
                        }
                }
                .onFailure { error in
                    print("❌ Failed to load guest image: \(imageName)")
                    print("❌ Error: \(error.localizedDescription)")
                }
                .retry(maxCount: 3)
                .cacheOriginalImage()
                .fade(duration: 0.25)
                .resizable()
                .scaledToFill()
                .frame(width: 93, height: 97)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            
            VStack(spacing: 2) {
                Text(name)
                    .font(.abeezeeItalic(size: 14))
                    .fontWeight(.medium)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                Text(role)
                    .font(.abeezeeItalic(size: 12))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(1)
            }
        }
        .frame(width: 120)
    }
}

struct LikedUsersView: View {
    @Binding var users: [UserProfile]
    
    // Number of users to display initially
    @State private var maxUsersToShow = 3
    
    var navigate: ((_ direction: Direction) -> Void)? = nil
    
    var body: some View {
        VStack(alignment: .center) {
            HStack {
                Text("Matched Profiles")
                    .font(.abeezeeItalic(size: 16))
                    .frame(maxWidth: .infinity, alignment: .leading)
                if users.count > maxUsersToShow {
                    Button(action: {
                        // TODO
                    }) {
                        Text("View All")
                            .font(.abeezeeItalic(size: 16))
                            .foregroundColor(.goldenBrown)
                            .padding(.vertical, 10)
                            .padding(.horizontal, 20)
                    }
                    .frame(maxWidth: .infinity, alignment: .trailing)
                }
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(users.prefix(maxUsersToShow), id: \.self) { user in
                        UserCardView(user: user) { direction in
                            if let navigate {
                                navigate(direction)
                                
                            }
                        }
                    }
                }
                .padding(.vertical)
                .padding(.horizontal, 4)
            }
        }
        .padding()
    }
}

struct UserCardView: View {
    @EnvironmentObject var userProfileModel: UserProfileModel
    
    let user: UserProfile
    
    var navigate: ((_ direction: Direction) -> Void)? = nil
    
    var body: some View {
        VStack(spacing: 8) {
            ZStack(alignment: .topTrailing) {
                KFImage(URL(string: user.profileImageUrl))
                    .resizable()
                    .scaledToFill()
                    .frame(width: 80, height: 80)
                    .clipShape(Circle())
                    .shadow(radius: 3)
            }
            Text(user.fullName)
                .font(.abeezeeItalic(size: 12))
            Button(action: {
                userProfileModel.currentMatchedProfile = user;
                if let navigate = navigate {
                    navigate(.forward)
                }
            }) {
                Text("Profile")
                    .font(.footnote)
                    .foregroundColor(.white)
                    .padding(.vertical, 6)
                    .padding(.horizontal, 20)
                    .background(.espresso)
                    .cornerRadius(8)
            }
        }
        .frame(maxWidth: 111, maxHeight: 129) // Fixed width for user cards
        .padding()
        .background(Color.white)
        .cornerRadius(5)
        .shadow(radius: 4)
    }
}

struct EventUser: Identifiable {
    let id: Int
    let name: String
    let imageName: String
}

// MARK: - Event Reservations View
struct EventReservationsView: View {
    @SwiftUI.Environment(\.dismiss) private var dismiss
    
    let event: Event
    let reservedUserProfiles: [UserProfile]
    
    var body: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 20) {
                // Header Section
                VStack(alignment: .leading, spacing: 12) {
                    Text("Event Reservations")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.espresso)
                    
                    Text(event.title)
                        .font(.headline)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal)
                .padding(.top)
                
                // Reservation Count
                HStack {
                    Image(systemName: "person.2.fill")
                        .foregroundColor(.sandstone)
                    Text("\(reservedUserProfiles.count) \(reservedUserProfiles.count == 1 ? "Reservation" : "Reservations")")
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
                .padding(.horizontal)
                
                // Reservations List
                if reservedUserProfiles.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "person.2.circle")
                            .font(.system(size: 60))
                            .foregroundColor(.gray.opacity(0.5))
                        
                        Text("No Reservations Yet")
                            .font(.title3)
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)
                        
                        Text("When people reserve your event, they'll appear here")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding()
                } else {
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            ForEach(reservedUserProfiles, id: \.self) { userProfile in
                                ReservationUserCard(userProfile: userProfile)
                            }
                        }
                        .padding(.horizontal)
                    }
                }
                
                Spacer()
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(.espresso)
                }
            }
        }
    }
}

// MARK: - Reservation User Card
struct ReservationUserCard: View {
    let userProfile: UserProfile
    
    var body: some View {
        HStack(spacing: 16) {
            // User Profile Image
            KFImage(URL(string: userProfile.profileImageUrl))
                .resizable()
                .scaledToFill()
                .frame(width: 60, height: 60)
                .clipShape(Circle())
                .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
            
            // User Info
            VStack(alignment: .leading, spacing: 4) {
                Text(userProfile.fullName)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                if !userProfile.bio.isEmpty {
                    Text(userProfile.bio)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                
                // Interests/Tags
                if !userProfile.interests.isEmpty {
                    HStack {
                        ForEach(userProfile.interests.prefix(3), id: \.self) { interest in
                            Text(interest)
                                .font(.caption)
                                .foregroundColor(.sandstone)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(Color.sandstone.opacity(0.1))
                                .cornerRadius(4)
                        }
                    }
                }
            }
            
            Spacer()
            
            // Status Icon
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
                .font(.title3)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
    }
}

#Preview {
    EventScreenView(event: try! Event(id: UUID(), title: "Drinks and Mingle", description: "String", date: "String", timeRange: "String", location: "String", createdBy: "String"))
}

