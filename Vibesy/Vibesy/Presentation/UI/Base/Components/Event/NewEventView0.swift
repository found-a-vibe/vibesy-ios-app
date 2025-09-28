//
//  NewEventView.swift
//  Vibesy
//
//  Created by Alexander Cleoni on 12/16/24.
//
import MapKit
import SwiftUI

struct NewEventView0: View {
    @EnvironmentObject var pageCoordinator: NewEventPageCoordinator
    
    @EnvironmentObject var authenticationModel: AuthenticationModel
    @EnvironmentObject var eventModel: EventModel
    
    @State private var tags: [String] = []
    @State private var eventTitle: String = ""
    @State private var eventLocation: String? = ""
    @State private var eventDate: Date = Date()
    @State private var startTime: Date = Date()
    @State private var endTime: Date = Date().addingTimeInterval(3600)
    @State private var eventDescription: String = ""
    
    @State private var isSelectingTime: Bool = false
    @Binding var isNewEventViewPresented: Bool
    
    @State private var goNext: Bool = false
    
    @State private var showSearchService: Bool = false
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack {
                    BackButtonView(systemImageName: "multiply") {
                        isNewEventViewPresented.toggle()
                    }
                    Text("Post Event")
                        .font(.abeezeeItalic(size: 26))
                        .foregroundStyle(.espresso)
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity, alignment: .center)
                }
                
                // Event Title
                VStack(alignment: .leading) {
                    Text("Event Title")
                        .font(.abeezee(size: 14))
                    HStack {
                        Image("Event")
                            .resizable()
                            .frame(width: 22, height: 22)
                            .imageScale(.small)
                        TextField("Event Title", text: $eventTitle)
                    }
                    .padding()
                    .background(RoundedRectangle(cornerRadius: 10).stroke(.gray, lineWidth: 1))
                }
                
                // Event Date
                VStack(alignment: .leading) {
                    Text("Event Date")
                        .font(.abeezee(size: 14))
                    HStack {
                        Image("Calendar")
                            .resizable()
                            .frame(width: 22, height: 22)
                            .imageScale(.small)
                        DatePicker("Select Date", selection: $eventDate, displayedComponents: .date)
                            .labelsHidden()
                        Spacer()
                        
                    }
                    .padding()
                    .background(RoundedRectangle(cornerRadius: 10).stroke(.gray, lineWidth: 1))
                }
                
                // Event Time Picker
                VStack(alignment: .leading) {
                    Text("Event Time")
                        .font(.abeezee(size: 14))
                    Button(action: {
                        isSelectingTime.toggle()
                    }) {
                        HStack {
                            Image("Clock")
                                .resizable()
                                .frame(width: 22, height: 22)
                                .imageScale(.small)
                            Text("\(formattedTimeRange(start: startTime, end: endTime))")
                                .foregroundColor(.black)
                            Spacer()
                            
                        }
                        .padding()
                        .background(RoundedRectangle(cornerRadius: 10).stroke(.gray, lineWidth: 1))
                    }
                }
                .sheet(isPresented: $isSelectingTime) {
                    TimePickerView(startTime: $startTime, endTime: $endTime, isPresented: $isSelectingTime)
                }
                // Event Location
                VStack(alignment: .leading) {
                    Text("Event Location")
                        .font(.abeezee(size: 14))
                    Button(action: {
                        showSearchService.toggle()
                    }) {
                        HStack {
                            Image("Location")
                                .resizable()
                                .frame(width: 22, height: 22)
                                .imageScale(.small)
                            Text("\(eventLocation ?? "Select Location")")
                                .foregroundColor(.black)
                            Spacer()
                            
                        }
                        .padding()
                        .background(RoundedRectangle(cornerRadius: 10).stroke(.gray, lineWidth: 1))
                    }
                }
                .sheet (isPresented: $showSearchService) {
                    if #available(iOS 16, *){
                        NavigationStack{
                            SearchView() {
                                eventLocation = $0
                                showSearchService.toggle()
                            } closeSearch: {
                                showSearchService.toggle()
                            }
                                .toolbar(.hidden, for: .navigationBar)
                        }
                    }else{
                        NavigationView{
                            SearchView() {
                                eventLocation = $0
                                showSearchService.toggle()
                            } closeSearch: {
                                showSearchService.toggle()
                            }
                                .navigationBarHidden(true)
                        }
                    }
                }
                
                
                // Event Details
                VStack(alignment: .leading) {
                    Text("Event Details")
                        .font(.abeezee(size: 14))
                    TextEditor(text: $eventDescription)
                        .frame(height: 100)
                        .padding()
                        .background(RoundedRectangle(cornerRadius: 10).stroke(.gray, lineWidth: 1))
                }
                
                VStack(alignment: .leading) {
                    Text("Event Tags")
                        .font(.abeezee(size: 14))
                    TagField(tags: $tags, placeholder: "Add Tags..")
                        .accentColor(.espresso)
                        .styled(.RoundedBorder)
                        .lowercase(false)
                }
                Button(
                    action: {
                        eventModel.newEvent?.title = eventTitle.aa_profanityFiltered("*")
                        eventModel.newEvent?.description = eventDescription.aa_profanityFiltered("*")
                        eventModel.newEvent?.location = eventLocation ?? ""
                        eventModel.newEvent?.date = formattedDate(date: eventDate)
                        eventModel.newEvent?.timeRange = formattedTimeRange(start: startTime, end: endTime)
                        tags.forEach { eventModel.newEvent?.hashtags.append($0.aa_profanityFiltered("*")) }
                        
                        goNext.toggle()
                    },
                    label: {
                        Text("Next")
                            .font(.custom("ABeeZee-Italic", size: 20))
                            .frame(maxWidth: .infinity, maxHeight: 51)
                            .foregroundStyle(.white)
                    }
                )
                .frame(height: 51)
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.roundedRectangle(radius: 8))
                .tint(.espresso)
                .padding(.vertical)
            }
            .padding()
        }
        .onAppear {
            _ = AAObnoxiousFilter.shared

            if eventModel.currentEventDetails != nil {
                tags = eventModel.currentEventDetails?.hashtags ?? []
                
                eventTitle = eventModel.currentEventDetails?.title ?? ""
                eventLocation = eventModel.currentEventDetails?.location ?? ""
                eventDate = parseDate(from: eventModel.currentEventDetails?.date ?? "") ?? Date()
                startTime = parseTimeRange(from: eventModel.currentEventDetails?.timeRange ?? "")?.start ?? Date()
                endTime = parseTimeRange(from: eventModel.currentEventDetails?.timeRange ?? "")?.end ?? Date().addingTimeInterval(3600)
                eventDescription = eventModel.currentEventDetails?.description ?? ""
            } else {
                try? eventModel.createNewEvent(userId: authenticationModel.state.currentUser?.id ?? "")
            }
        }
        .onTapGesture {
            hideKeyboard()
        }
        .scrollDismissesKeyboard(.interactively)
        .navigationDestination(isPresented: $goNext) {
            NewEventView1(isNewEventViewPresented: $isNewEventViewPresented)
                .navigationBarBackButtonHidden()
        }
    }
}

struct TimePickerView: View {
    @Binding var startTime: Date
    @Binding var endTime: Date
    @Binding var isPresented: Bool
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Start Time")) {
                    DatePicker("Select Start Time", selection: $startTime, displayedComponents: .hourAndMinute)
                        .labelsHidden()
                }
                Section(header: Text("End Time")) {
                    DatePicker("Select End Time", selection: $endTime, displayedComponents: .hourAndMinute)
                        .labelsHidden()
                }
            }
            .navigationBarTitle("Select Time", displayMode: .inline)
            .navigationBarItems(trailing: Button("Done") {
                isPresented = false
            })
        }
    }
}

extension NewEventView0 {
    /// Formats a given start and end `Date` into a readable time range string.
    /// Example: `formattedTimeRange(start: Date(), end: Date())` → "3:00 PM - 5:00 PM"
    /// - Parameters:
    ///   - start: The start time as a `Date` object.
    ///   - end: The end time as a `Date` object.
    /// - Returns: A formatted string representing the time range (e.g., `"3:00 PM - 5:00 PM"`).
    private func formattedTimeRange(start: Date, end: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short // Uses system locale for short time format
        return "\(formatter.string(from: start)) - \(formatter.string(from: end))"
    }
    
    /// Formats a given `Date` into a short date string.
    /// Example: `formattedDate(date: Date())` → "3/7/25"
    /// - Parameter date: The `Date` object to format.
    /// - Returns: A formatted date string in short style (e.g., `"3/7/25"` for US locale).
    private func formattedDate(date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short // Uses system locale for short date format
        return formatter.string(from: date)
    }
    
    //// Parses a formatted time range string into `Date` objects for the start and end times.
    /// Example: `parseTimeRange(from: "3:00 PM - 5:00 PM")` → `(start: Date, end: Date)`
    /// - Parameter timeRange: A string representing the time range (e.g., `"3:00 PM - 5:00 PM"`).
    /// - Returns: A tuple containing `start` and `end` as `Date` objects, or `nil` if parsing fails.
    private func parseTimeRange(from timeRange: String) -> (start: Date, end: Date)? {
        let formatter = DateFormatter()
        formatter.timeStyle = .short // Matches system locale's short time format
        formatter.dateStyle = .none  // Ensures only time is parsed
        
        let components = timeRange.components(separatedBy: " - ")
        guard components.count == 2,
              let startTime = formatter.date(from: components[0]),
              let endTime = formatter.date(from: components[1]) else {
            print("Failed to parse time range: \(timeRange)")
            return nil
        }
        return (startTime, endTime)
    }
    
    /// Parses a short date string into a `Date` object.
    /// Example: `parseDate(from: "3/7/25")` → `Date`
    /// - Parameter dateString: A string representing the date (e.g., `"3/7/25"` for US locale).
    /// - Returns: A `Date` object if parsing succeeds, or `nil` if parsing fails.
    private func parseDate(from dateString: String) -> Date? {
        let formatter = DateFormatter()
        formatter.dateStyle = .short // Matches system locale's short date format
        return formatter.date(from: dateString)
    }
}

#Preview {
    NewEventView0(isNewEventViewPresented: .constant(true))
}

