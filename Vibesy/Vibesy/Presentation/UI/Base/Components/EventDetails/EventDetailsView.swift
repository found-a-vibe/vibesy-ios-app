//
//  EventDetailsView.swift
//  Vibesy
//
//  Created by Alexander Cleoni on 3/6/25.
//

import Kingfisher
import SwiftUI
import WebKit

struct WebView: UIViewRepresentable {
    let url: URL

    func makeUIView(context: Context) -> WKWebView {
        return WKWebView()
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        let request = URLRequest(url: url)
        uiView.load(request)
    }
}

struct EventScreenView: View {
    @SwiftUI.Environment(\.dismiss) var dismiss

    @EnvironmentObject var eventModel: EventModel
    @EnvironmentObject var userProfileModel: UserProfileModel
    @EnvironmentObject var interactionModel: InteractionModel
    @EnvironmentObject var authenticationModel: AuthenticationModel
    
    @State private var isNewEventViewPresented: Bool = false
    
    @State var event: Event = Event(id: UUID(), title: "", description: "", date: "", timeRange: "", location: "", images: [""], createdBy: "")
    
    @State private var eventIsLiked: Bool = false
    
    @State var goNext: Bool = false
    
    var handleNavigation = false
    
    var enableAdminMode: Bool = false
    
    var systemImageName: String? = nil
    
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
                        EventImageView(title: event.title, eventImage: image, eventIsLiked: eventIsLiked, enableAdminMode: enableAdminMode, interactWithEvent: interactWithEvent)
                        // Event Details
                        EventDetailsView(description: event.description, location: event.location, date: event.date, timeRange: event.timeRange)
                        // Tags
                        TagsView(tags: event.hashtags)
                        // Speaker/Guest Section
                        if event.guests.count > 0 {
                            SpeakerGuestView(guests: event.guests)
                        }
                        
                        if event.priceDetails.count > 0 {
                            PriceDetailsView(priceDetails: event.priceDetails)
                        }
                        
                        // Footer Section
                        LikedUsersView(users: $userProfileModel.matchedProfiles) { direction in
                            if let navigate {
                                goNext = true
                                navigate(direction)
                            }
                        }
                    }
                    .sheet(isPresented: $showWebView) {
//                        WebView(url: URL(string: event.priceDetails.link ?? "")!)
                    }
                    .padding()
                }
                if eventIsLiked {
                    VStack(alignment: .center) {
                        Button(action: {
//                            showWebView.toggle()
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
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                    .padding()
                }
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
                        eventModel.deleteEvent()
                        eventModel.removeCurrentEventDetails()
                    })
                } label: {
                    Image(systemName: "ellipsis")
                }
                .padding()
            }
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
            if !enableAdminMode {
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
                    .foregroundColor(.espresso)
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
                ForEach(guests, id: \.self) { guest in
                    GuestCardView(name: guest.name, imageName: guest.imageUrl ?? "")
                }
            }
        }
    }
}

struct PriceDetailsView: View {
    let priceDetails: [PriceDetails]

    var body: some View {
        VStack(alignment: .center) {
            Text("Event Price")
                .font(.abeezeeItalic(size: 16))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding([.top, .horizontal])
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack {
                    ForEach(priceDetails, id: \.self) { price in
                        VStack {
                            Text(price.title)
                            Text(price.price)
                        }
                    }
                }
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
