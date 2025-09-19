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
    
    @State private var isNewEventViewPresented: Bool = false
    
    @State var event: Event = Event(id: UUID(), title: "", description: "", date: "", timeRange: "", location: "", images: [""], createdBy: "")
    
    @State private var eventIsLiked: Bool = false
    @State private var eventIsReserved: Bool = false
    
    @State var goNext: Bool = false
    
    var handleNavigation = false
    
    var enableAdminMode: Bool = false
    
    var systemImageName: String? = nil
    
    @State var showReservationConfirmation: Bool = false
    @State var showReservationCancellation: Bool = false
    
    @State private var showWebView = false
    
    var navigate: ((_ direction: Direction) -> Void)? = nil
    
    func checkLikedEvents() {
        let likedEvents = eventModel.currentEventDetails?.getLikes() ?? []
        let uid = authenticationModel.state.currentUser?.id
        
        if let uid {
            let found = likedEvents.first (where: { $0 == uid})
            if found != nil {
                eventIsLiked = true
            }
        }
    }
    
    func checkedReservedEvents() {
        let reservedEvents = eventModel.currentEventDetails?.getReservations() ?? []
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
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        // Event Image
                        EventImageView(title: event.title, eventImage: image, eventIsLiked: eventIsLiked, eventIsReserved: eventIsReserved, enableAdminMode: enableAdminMode, interactWithEvent: interactWithEvent)
                        // Event Details
                        EventDetailsView(description: event.description, location: event.location, date: event.date, timeRange: event.timeRange)
                        // Tags
                        TagsView(tags: event.hashtags)
                        // Speaker/Guest Section
                        if event.guests.count > 0 {
                            SpeakerGuestView(guests: event.guests)
                        }
                        
                        PriceDetailsView(priceDetails: event.priceDetails, showWebView: $showWebView, eventIsReserved: $eventIsReserved)
                        
                        // Footer Section
                        LikedUsersView(users: $userProfileModel.matchedProfiles) { direction in
                            if let navigate {
                                goNext = true
                                navigate(direction)
                            }
                        }
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
                    .sheet(isPresented: $showWebView) {
                        WebView(url: URL(string: event.priceDetails[0].link ?? "")!)
                    }
                    .padding()
                }
                
                VStack(alignment: .center) {
                    if eventIsLiked && !enableAdminMode {
                        Button(action: {
                            showReservationConfirmation.toggle()
                            reserveEvent()
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
                    
                    if eventIsReserved {
                        Button(action: {
                            showReservationCancellation.toggle()
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
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                .padding()
                
            }
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
        .background(Color.white)
        .onAppear {
            if let userId = authenticationModel.state.currentUser?.id, let details = eventModel.currentEventDetails {
                event = details
                userProfileModel.getMatchedUsersProfiles(userId: userId,userIds: event.likes.filter { $0 != userId})
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
        .onDisappear {
            userProfileModel.resetMatchedUsersProfiles()
        }
    }
}



// MARK: - Header View
struct HeaderView: View {
    @EnvironmentObject var eventModel: EventModel
    @EnvironmentObject var interactionModel: InteractionModel
    @EnvironmentObject var authenticationModel: AuthenticationModel
    
    @State var showFlagContentView = false
    
    @Binding var isNewEventViewPresented: Bool
    
    var enableAdminMode: Bool = false
    
    var systemImageName: String? = nil
    
    var navigate: ((_ direction: Direction) -> Void)? = nil
    
    var body: some View {
        HStack {
            BackButtonView(systemImageName: systemImageName) {
                eventModel.removeCurrentEventDetails()
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
                        Task {
                            do {
                                try await eventModel.deleteEvent()
                                eventModel.removeCurrentEventDetails()
                            } catch {
                            }
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
                    interactionModel.unlikeEvent(userId: user.id, eventId: currentEventDetails.id.uuidString)
                    interactionModel.dislikeEvent(userId: user.id, eventId: currentEventDetails.id.uuidString)
                    eventModel.events.removeAll(where: { $0.id.uuidString == currentEventDetails.id.uuidString})
                    eventModel.removeCurrentEventDetails()
                }
            }
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
            .presentationCornerRadius(24)
            .interactiveDismissDisabled(false)
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
    
    var interactWithEvent: (() -> Void)
    
    var body: some View {
        ZStack(alignment: .bottomLeading) {
            KFImage(URL(string: eventImage ?? ""))
                .resizable()
                .scaledToFill()
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
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
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
                Text("#\(tag)")
                    .font(.caption)
                    .foregroundColor(.white)
                    .padding(6)
                    .background(.goldenBrown)
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
                ForEach(guests, id: \.self) { guest in
                    GuestCardView(name: guest.name, imageName: guest.imageUrl ?? "")
                }
            }
        }
    }
}

struct PriceDetailsView: View {
    let priceDetails: [PriceDetails]
    @Binding var showWebView: Bool
    @Binding var eventIsReserved: Bool
    
    var body: some View {
        VStack(alignment: .center) {
            Text("Event Price")
                .font(.abeezeeItalic(size: 16))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding([.top, .horizontal])
            
            if priceDetails.count > 0 {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(priceDetails, id: \.self) { price in
                            VStack(alignment: .center, spacing: 8) {
                                if let link = price.link {
                                    if !link.isEmpty {
                                        Text("View Tickets Online")
                                            .font(.abeezeeItalic(size: 14))
                                            .foregroundStyle(.sandstone)
                                            .underline()
                                            .onTapGesture {
                                                showWebView.toggle()
                                            }
                                        
                                        
                                        
                                    }
                                } else {
                                    Text(price.title)
                                        .font(.abeezeeItalic(size: 14))
                                    Text("$\(price.price)")
                                        .font(.abeezeeItalic(size: 14))
                                        .foregroundStyle(.sandstone)
                                }
                            }
                        }
                    }
                    .padding(.horizontal)
                }
            } else {
                Text("Free Event")
            }
        }
    }
}

struct GuestCardView: View {
    var name: String
    var imageName: String
    
    var body: some View {
        VStack(spacing: 8) {
            KFImage(URL(string: imageName))
                .resizable()
                .scaledToFill()
                .frame(width: 93, height: 97)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            Text(name)
                .font(.abeezeeItalic(size: 16))
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


#Preview {
    EventScreenView(event: Event(id: UUID(), title: "Drinks and Mingle", description: "String", date: "String", timeRange: "String", location: "String", hashtags: ["#music", "#vibes"], createdBy: "String"))
}
