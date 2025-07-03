//
//  CardView.swift
//  FoundAVibe
//
//  Created by Alexander Cleoni on 10/21/24.
//

import SwiftUI
import Kingfisher

struct CardView: View {
    @EnvironmentObject var authenticationModel: AuthenticationModel

    @EnvironmentObject var eventModel: EventModel
    @EnvironmentObject var userProfileModel: UserProfileModel
    @EnvironmentObject var interactionModel: InteractionModel
    
    @State private var xOffset: CGFloat = 0
    @State private var degrees: Double = 0
    @State private var currentImageIndex: Int = 0
    @State private var showFullEventInfo: Bool = false
        
    var event: Event
    
    var image: String {
        if event.images.count > 0 {
            return event.images[currentImageIndex]
        }
        print("NO IMAGE AVAILABLE")
        return "https://upload.wikimedia.org/wikipedia/commons/1/14/No_Image_Available.jpg"
    }
    
    @Binding var alert: String
        
    var body: some View {
        ZStack(alignment: .bottom) {
            ZStack(alignment: .top) {
                KFImage(URL(string: image))
                    .resizable()
                    .aspectRatio(CGSize(width: SizeConstants.width, height: SizeConstants.height), contentMode: .fill)
                    .overlay(ImageScrollingOverlayView(currentImageIndex: $currentImageIndex, totalImageCount: imageCount - 1))
                CardImageIndicatorView(currentIndex: currentImageIndex, totalImageCount: imageCount)
                    .padding()
                SwipeActionIndicatorView(xOffset: $xOffset)
            }
            EventInfoView(title: event.title, location: event.location, description: event.description, showFullEventInfo: $showFullEventInfo)
        }
        .fullScreenCover(isPresented: $showFullEventInfo) {
            NavigationStack {
                EventScreenView(handleNavigation: true, systemImageName: "xmark") { direction in
                    if direction != .forward {
                        eventModel.removeCurrentEventDetails()
                        showFullEventInfo.toggle()
                    }
                }
            }
            .onAppear {
                eventModel.setCurrentEventDetails(event)
            }
        }
        .onReceive(eventModel.$buttonSwipeAction, perform: { action in
            onRecieveSwipeAction(action)
        })
        .frame(width: SizeConstants.width, height: SizeConstants.height)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .offset(x: xOffset)
        .rotationEffect(.degrees(degrees))
        .animation(.snappy, value: xOffset)
        .gesture(
            DragGesture()
                .onChanged(onDragChanged)
                .onEnded(onDragEnded)
        )
        .onAppear {
            print(event.id.uuidString)
            print(event.images)
        }
    }
}

private extension CardView {
    var imageCount: Int {
        return event.images.count
    }
}

private extension CardView {
    func returnToCenter() {
        xOffset = 0
        degrees = 0
    }
    
    func swipeLeft() {
        withAnimation {
            xOffset = -500
            degrees = -12
        } completion: {
            alert = "left"
            eventModel.buttonSwipeAction = nil
            if let uid = authenticationModel.state.currentUser?.id {
                interactionModel.dislikeEvent(userId: uid, eventId: event.id.uuidString)
                eventModel.removeEventFromFeed(event)
            }
        }
    }
    
    func swipeRight() {
        withAnimation {
            xOffset = 500
            degrees = 12
        } completion: {
            alert = "right"
            eventModel.buttonSwipeAction = nil
            if let uid = authenticationModel.state.currentUser?.id {
                interactionModel.likeEvent(userId: uid, eventId: event.id.uuidString)
                eventModel.removeEventFromFeed(event)
            }
        }
    }
    
    func onRecieveSwipeAction(_ action: Action?) {
        guard let action else { return }
        let topCard = eventModel.events.last
        
        if topCard == event {
            switch action {
            case .like:
                swipeRight()
            case .reject:
                swipeLeft()
            case .refresh:
                if let uid = authenticationModel.state.currentUser?.id {
                    eventModel.fetchEventFeed(uid: uid)
                }
            }
        }
    }
}

private extension CardView {
    func onDragChanged(_ value: _ChangedGesture<DragGesture>.Value) {
        xOffset = value.translation.width
        degrees = Double(value.translation.width / 25)
    }
    
    func onDragEnded(_ value: _ChangedGesture<DragGesture>.Value) {
        let width = value.translation.width
        
        if abs(width) < abs(SizeConstants.screenCutoff) {
            returnToCenter()
            return
        }
        
        if width >= SizeConstants.screenCutoff {
            swipeRight()
        } else {
            swipeLeft()
        }
    }
}

#Preview {
    CardView(event: Event(id: UUID(), title: "String", description: "String", date: "String", timeRange: "String", location: "String", createdBy: "String"), alert: .constant(""))
}
