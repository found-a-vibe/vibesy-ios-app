//
//  EventListView.swift
//  Vibesy
//
//  Created by Alexander Cleoni on 3/6/25.
//

import SwiftUI
import Kingfisher

struct SearchBarView: View {
    @Binding var searchText: String // Changed to a Binding
    
    var body: some View {
        VStack {
            TextField("Search...", text: $searchText)
                .padding(10)
                .background(Color(.systemGray6))
                .cornerRadius(8)
                .padding(.horizontal)
        }
    }
}

struct EventsHeaderView: View {
    var headerText: String
    var profileImageUrl: String?
    var exitButtonAction: (() -> Void)?
    
    var body: some View {
        HStack {
            if let url = profileImageUrl, url != "" {
                KFImage(URL(string: url))
                    .resizable()
                    .scaledToFill()
                    .clipShape(Circle())
                    .shadow(radius: 5)
                    .frame(width: 48, height: 48)
            } else if let url = profileImageUrl, url == "" {
                
            } else {
                BackButtonView {
                    if let exitButtonAction {
                        exitButtonAction()
                    }
                }
            }
            Spacer()
            Text(headerText)
                .foregroundStyle(.espresso)
                .font(.abeezeeItalic(size: 26))
            Spacer()
        }
        .padding(.horizontal)
    }
}

struct EventCard: View {
    @EnvironmentObject var authenticationModel: AuthenticationModel
    @EnvironmentObject var interactionModel: InteractionModel
    @EnvironmentObject var eventModel: EventModel
        
    var event: Event
    var showIcon: Bool
    var setEventDetails: ((Event) -> Void)? = nil
    
    var image: String {
        if event.images.count > 0 {
            return event.images[0]
        }
        print("NO IMAGE AVAILABLE")
        return "https://upload.wikimedia.org/wikipedia/commons/1/14/No_Image_Available.jpg"
    }
    
    var body: some View {
        RoundedRectangle(cornerRadius: 10)
            .fill(Color.white)
            .frame(width: 174, height: 174)
            .shadow(radius: 5)
            .overlay {
                KFImage(URL(string: image))
                    .resizable()
                    .aspectRatio(
                        event.isUserGenerated ? 1 : nil,
                        contentMode: event.isUserGenerated ? .fill : .fit
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay {
                        VStack {
                            if (showIcon) {
                                Image(systemName: "heart.fill")
                                    .resizable()
                                    .foregroundStyle(.red)
                                    .frame(width: 20, height: 20)
                                    .onTapGesture {
                                        if let uid = authenticationModel.state.currentUser?.id {
                                            interactionModel.unlikeEvent(userId: uid, eventId: event.id.uuidString)
                                            eventModel.removeLikedEvent(event)
                                        }
                                    }
                                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                                    .padding()
                            }
                            Spacer()
                            VStack(alignment: .leading) {
                                Text(event.title)
                                    .font(.abeezeeItalic(size: 16))
                                    .foregroundStyle(.white)
                                    .bold()
                            }
                            .background(
                                LinearGradient(colors: [.clear, .black], startPoint: .top, endPoint: .bottom)
                            )
                        }
                    }
            }
            .onTapGesture {
                if let setEventDetails {
                    setEventDetails(event)
                }
            }
    }
}

struct EventListView: View {
    @EnvironmentObject var authenticationModel: AuthenticationModel
    @EnvironmentObject var eventModel: EventModel
    @EnvironmentObject var userProfileModel: UserProfileModel
    
    @State private var searchText: String = ""
    @State private var showEventDetails: Bool = false
    
    var eventsHeaderViewText: String
    var showEventCardIcon: Bool = false
    var eventsByStatus: EventStatus
    var profileImageUrl: String? = nil
    
    var navigate: ((_ direction: Direction) -> Void)? = nil
    
    var columns = [GridItem(.adaptive(minimum: 160), spacing: 20)]
    
    var filteredEvents: [Event] {
        var events: [Event]
        
        switch eventsByStatus {
        case .likedEvents:
            events = eventModel.likedEvents
        case .postedEvents:
            events = eventModel.postedEvents
        case .reservedEvents:
            events = eventModel.reservedEvents
        default:
            events = []
        }
        
        if searchText.isEmpty {
            return events
        } else {
            return events.filter { event in
                doesSearchMatch(query: searchText, text: event.title)
            }
        }
    }
    
    /// Matches the search query against the event title, handling multi-line and word boundaries
    func doesSearchMatch(query: String, text: String) -> Bool {
        let query = query.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedText = text
            .lowercased()
            .replacingOccurrences(of: "\n", with: " ") // Replace line breaks with spaces
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Split into words for more granular matching
        let words = normalizedText.components(separatedBy: .whitespacesAndNewlines)
        
        // Check if the query matches any word or part of the full text
        return normalizedText.localizedCaseInsensitiveContains(query) ||
        words.contains(where: { $0.localizedCaseInsensitiveContains(query) })
    }
    
    var body: some View {
        VStack {
            EventsHeaderView(headerText: eventsHeaderViewText, profileImageUrl: profileImageUrl) {
                if let navigate {
                    navigate(.root)
                }
            }
            SearchBarView(searchText: $searchText)
            if eventModel.isLoading {
                VStack {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                        .tint(.espresso)
                        .scaleEffect(1.5) // Adjust size if needed
                        .padding()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 10) {
                        ForEach(filteredEvents) { event in
                            EventCard(event: event, showIcon: showEventCardIcon) { event in
                                eventModel.setCurrentEventDetails(event)
                                if let navigate {
                                    navigate(.forward)
                                }
                            }
                        }
                    }
                }
                .padding()
            }
        }
        .task {
            if let uid = authenticationModel.state.currentUser?.id {
                await eventModel.getEventsByStatus(uid: uid, status: eventsByStatus)
            }
        }
    }
}

#Preview {
    EventListView(eventsHeaderViewText: "Events", eventsByStatus: .attendedEvents)
}
