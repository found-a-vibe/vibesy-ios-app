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
    @State var showReservationConfirmation: Bool = false
    @State var showReservationCancellation: Bool = false
    @State var showReservationSheet: Bool = false
    @State private var showTicketListView: Bool = false
    @State private var showPaidEventCancellationAlert: Bool = false
    @State private var showReservationsView: Bool = false
    @State private var showWebView = false
    @State private var reservedUserProfiles: [UserProfile] = []

    var handleNavigation = false
    var enableAdminMode: Bool = false
    var navigationSource: EventStatus? = nil
    var systemImageName: String? = nil
    var cardView: Bool? = false
    var navigate: ((_ direction: Direction) -> Void)? = nil

    // Computed property to check if current user is the event creator
    var isCurrentUserEventCreator: Bool {
        guard let currentUserId = authenticationModel.state.currentUser?.id
        else { return false }
        return event.isCreatedBy(currentUserId)
    }

    // Computed property to check if user has purchased tickets for this paid event
    var hasPurchasedTickets: Bool {
        guard let currentUserId = authenticationModel.state.currentUser?.id
        else { return false }
        return event.hasInternalPricing && eventIsReserved
            && userOrdersService.hasPurchasedTickets(
                for: event.id.uuidString,
                userId: currentUserId
            )
    }

    // Get the order ID for ticket viewing
    var orderIdForTickets: Int? {
        guard let currentUserId = authenticationModel.state.currentUser?.id
        else { return nil }
        return userOrdersService.getOrderId(
            for: event.id.uuidString,
            userId: currentUserId
        )
    }

    // Computed property to check if there's a bottom button showing
    var hasBottomButton: Bool {
        return
            (eventIsLiked && !enableAdminMode && !isCurrentUserEventCreator
            && !eventIsReserved)
            || (eventIsReserved && !isCurrentUserEventCreator)
    }

    func checkLikedEvents() {
        let likedEvents = Array(eventModel.currentEventDetails?.likes ?? [])
        let uid = authenticationModel.state.currentUser?.id

        if let uid {
            let found = likedEvents.first(where: { $0 == uid })
            if found != nil {
                eventIsLiked = true
            }
        }
    }

    func checkedReservedEvents() {
        let reservedEvents = Array(
            eventModel.currentEventDetails?.reservations ?? []
        )
        let uid = authenticationModel.state.currentUser?.id

        if let uid {
            let found = reservedEvents.first(where: { $0 == uid })
            if found != nil {
                eventIsReserved = true
            }
        }
    }

    func interactWithEvent() {
        if eventIsLiked {
            eventModel.buttonSwipeAction = nil
            if let uid = authenticationModel.state.currentUser?.id {
                interactionModel.unlikeEvent(
                    userId: uid,
                    eventId: event.id.uuidString
                ) {
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
            interactionModel.reserveEvent(
                userId: uid,
                eventId: event.id.uuidString
            )
        }
    }

    func cancelEventReservation() {
        if let uid = authenticationModel.state.currentUser?.id {
            interactionModel.cancelEventReservation(
                userId: uid,
                eventId: event.id.uuidString
            ) {
                if let navigate {
                    navigate(.back)
                }
            }

        }
    }

    func loadReservedUserProfiles() {
        guard let userId = authenticationModel.state.currentUser?.id else {
            return
        }
        let reservedUserIds = event.reservations

        if !reservedUserIds.isEmpty {
            // Clear existing profiles first
            reservedUserProfiles = []

            // Fetch profiles asynchronously - they will be updated via onReceive
            userProfileModel.getMatchedUsersProfiles(
                userId: userId,
                userIds: reservedUserIds
            )
        } else {
            reservedUserProfiles = []
        }
    }

    var image: String {
        if event.images.count > 0 {
            return event.images[0]
        }
        return
            "https://upload.wikimedia.org/wikipedia/commons/1/14/No_Image_Available.jpg"
    }

    var body: some View {
        VStack {
            // Header Section
            EventScreenHeaderView(
                isNewEventViewPresented: $isNewEventViewPresented,
                enableAdminMode: enableAdminMode,
                systemImageName: systemImageName,
                navigate: navigate
            )

            ZStack {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 16) {
                        // Event Image
                        if let cardView, cardView == true {
                            EventScreenImageView(
                                eventImage: image,
                                eventIsLiked: eventIsLiked,
                                eventIsReserved: eventIsReserved,
                                enableAdminMode: enableAdminMode,
                                isUserGenerated: event.isUserGenerated,
                                interactWithEvent: interactWithEvent
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 20))
                            .padding(.horizontal)
                        } else {
                            EventScreenImageView(
                                eventImage: image,
                                eventIsLiked: eventIsLiked,
                                eventIsReserved: eventIsReserved,
                                enableAdminMode: enableAdminMode,
                                isUserGenerated: event.isUserGenerated,
                                interactWithEvent: interactWithEvent
                            )
                        }

                        EventTitleView(
                            eventTitle: event.title
                        )

                        if let cardView, cardView == true {
                            VStack {
                                // Event Details
                                EventDetailsContentView(
                                    location: event.location,
                                    date: event.date,
                                    timeRange: event.timeRange,
                                )

                                // Price Details
                                EventPriceView(
                                    event: event,
                                    showWebView: $showWebView,
                                    eventIsReserved: $eventIsReserved
                                )

                                EventLikesAndReservationsView(
                                    likesCount: event.likeCount,
                                    reservationsCount: event.reservationCount
                                )

                                EventDescriptionView(
                                    description: event.description
                                )

                                // Tags
                                EventTagsView(tags: event.hashtags)
                            }
                            .background(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 20))
                            .padding(.horizontal)
                        } else {
                            VStack {
                                // Event Details
                                EventDetailsContentView(
                                    location: event.location,
                                    date: event.date,
                                    timeRange: event.timeRange,
                                )

                                // Price Details
                                EventPriceView(
                                    event: event,
                                    showWebView: $showWebView,
                                    eventIsReserved: $eventIsReserved
                                )

                                EventLikesAndReservationsView(
                                    likesCount: event.likeCount,
                                    reservationsCount: event.reservationCount
                                )

                                EventDescriptionView(
                                    description: event.description
                                )

                                // Tags
                                EventTagsView(tags: event.hashtags)
                            }
                            .background(.white)
                        }

                        // Speaker/Guest Section
                        if event.guests.count > 0 {
                            EventSpeakerGuestView(guests: event.guests)
                        }

                        // Matched Profiles
                        EventLikedUsersView(
                            users: $userProfileModel.matchedProfiles
                        ) { direction in
                            if let navigate {
                                goNext = true
                                navigate(direction)
                            }
                        }

                        // Add spacing for bottom button
                        Spacer(minLength: hasBottomButton ? 80 : 20)
                    }
                    .overlay(alignment: .center) {
                        if showReservationConfirmation
                            || showReservationCancellation
                        {
                            ReservationConfirmationOverlay(
                                isConfirmation: showReservationConfirmation,
                                onConfirm: {
                                    if showReservationConfirmation {
                                        showReservationConfirmation.toggle()
                                        interactWithEvent()
                                    }
                                    if showReservationCancellation {
                                        showReservationCancellation.toggle()
                                        cancelEventReservation()
                                    }
                                }
                            )
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
            }

            VStack(alignment: .center) {
                // Show Reserve button for non-creators
                if eventIsLiked && !enableAdminMode
                    && !isCurrentUserEventCreator && !eventIsReserved
                {
                    Button(action: {
                        showReservationSheet = true
                    }) {
                        Text("Reserve")
                            .font(.aBeeZeeRegular(size: 12))
                            .foregroundColor(.white)
                            .frame(width: 124, height: 28)
                            .padding(2)
                            .background(.espresso)
                            .cornerRadius(8)
                    }
                }

                // Show View Reservations button for event creators (only from posted events tab)
                if isCurrentUserEventCreator
                    && navigationSource == .postedEvents
                {
                    Button(action: {
                        // Reset and load fresh profile data
                        userProfileModel.resetMatchedUsersProfiles()
                        loadReservedUserProfiles()
                        showReservationsView = true
                    }) {
                        Text("View Guest List")
                            .font(.aBeeZeeRegular(size: 12))
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
                                    .font(.aBeeZeeRegular(size: 12))
                                    .foregroundColor(.white)
                                    .frame(width: 124, height: 28)
                                    .padding(2)
                                    .background(.goldenBrown)
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
                                .font(.aBeeZeeRegular(size: 12))
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
        .background(
            RadialGradient(
                gradient: Gradient(
                    colors: [.espresso, .goldenBrown]),
                center: .center,
                startRadius: 0,
                endRadius: 300
            )
        )
        .navigationDestination(
            isPresented: handleNavigation ? $goNext : .constant(false)
        ) {
            MatchedUserDetailsView()
                .navigationBarBackButtonHidden()
        }
        .fullScreenCover(isPresented: $isNewEventViewPresented) {
            NavigationStack {
                NewEventView0(isNewEventViewPresented: $isNewEventViewPresented)
            }
        }
        .alert(
            "Paid Event Cancellation",
            isPresented: $showPaidEventCancellationAlert
        ) {
            Button("Email Support") {
                if let url = URL(
                    string:
                        "mailto:foundavibellc@gmail.com?subject=Ticket%20Refund%20Request&body=Hello,%0D%0A%0D%0AI%20would%20like%20to%20request%20a%20refund%20for%20my%20ticket%20purchase%20for%20the%20event:%20\(event.title.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? event.title)%0D%0A%0D%0APlease%20let%20me%20know%20the%20next%20steps.%0D%0A%0D%0AThank%20you!"
                ) {
                    UIApplication.shared.open(url)
                }
            }
            Button("Cancel", role: .cancel) {
                showPaidEventCancellationAlert = false
            }
        } message: {
            Text(
                "To cancel your paid reservation and request a refund, please contact our customer support team at foundavibellc@gmail.com. We'll help you process your refund request."
            )
        }
        .background(Color.white)
        .onAppear {
            if let userId = authenticationModel.state.currentUser?.id,
                let details = eventModel.currentEventDetails
            {
                event = details

                // Debug event details
                print("EventDetailsView loaded for event: \(event.title)")
                print("Event has \(event.guests.count) guests:")
                for guest in event.guests {
                    print(
                        "  - \(guest.name) (\(guest.role)): ImageURL = \(guest.imageUrl?.isEmpty == false ? guest.imageUrl! : "[EMPTY or NIL]")"
                    )
                }

                userProfileModel.getMatchedUsersProfiles(
                    userId: userId,
                    userIds: event.likes.filter { $0 != userId }
                )

                // Preload guest images to warm cache
                EventImagePreloader.preloadGuestImages(for: event)
            }
            checkLikedEvents()
            checkedReservedEvents()
        }
        .onChange(of: eventModel.currentEventDetails) { _, newDetails in
            if let details = newDetails,
                let userId = authenticationModel.state.currentUser?.id
            {
                event = details

                // Debug event details
                print("EventDetailsView updated for event: \(event.title)")

                userProfileModel.getMatchedUsersProfiles(
                    userId: userId,
                    userIds: event.likes.filter { $0 != userId }
                )

                // Preload guest images to warm cache
                EventImagePreloader.preloadGuestImages(for: event)

                checkLikedEvents()
                checkedReservedEvents()
            }
        }
        .onChange(of: eventModel.events) { _, updatedEvents in
            guard
                updatedEvents.firstIndex(where: {
                    $0.id.uuidString == event.id.uuidString
                }) != nil
            else {
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
            EventImagePreloader.preloadMatchedProfileImages(profiles: profiles)
        }
        .onDisappear {
            userProfileModel.resetMatchedUsersProfiles()
        }
    }
}

#Preview {
    EventScreenView(
        event: try! Event(
            id: UUID(),
            title: "Drinks and Mingle",
            description: "String",
            date: "String",
            timeRange: "String",
            location: "String",
            createdBy: "String"
        )
    )
}
