//
//  CardView.swift
//  FoundAVibe
//
//  Created by Alexander Cleoni on 10/21/24.
//

import SwiftUI
import Kingfisher
import os.log

struct CardView: View {
    private static let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "Vibesy", category: "CardView")
    
    // MARK: - Environment
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityDifferentiateWithoutColor) private var differentiateWithoutColor
    
    // MARK: - Environment Objects
    @EnvironmentObject var authenticationModel: AuthenticationModel
    @EnvironmentObject var eventModel: EventModel
    @EnvironmentObject var userProfileModel: UserProfileModel
    @EnvironmentObject var interactionModel: InteractionModel
    
    // MARK: - State
    @State private var xOffset: CGFloat = 0
    @State private var degrees: Double = 0
    @State private var currentImageIndex: Int = 0
    @State private var showFullEventInfo: Bool = false
    @State private var showErrorAlert = false
    @State private var errorMessage = ""
    @State private var isProcessingAction = false
    
    // MARK: - Properties
    let event: Event
    @Binding var alert: String
    
    // MARK: - Computed Properties
    private var currentImageURL: String {
        guard !event.images.isEmpty, currentImageIndex < event.images.count else {
            Self.logger.warning("No image available for event: \(event.id)")
            return "https://upload.wikimedia.org/wikipedia/commons/1/14/No_Image_Available.jpg"
        }
        return event.images[currentImageIndex]
    }
    
    private var imageCount: Int {
        event.images.count
    }
    
    private var hasMultipleImages: Bool {
        imageCount > 1
    }
    
    private var swipeThreshold: CGFloat {
        SizeConstants.screenCutoff
    }
    
    // MARK: - Body
    var body: some View {
        ZStack(alignment: .bottom) {
            // Main image and overlays
            ZStack(alignment: .top) {
                eventImage
                imageOverlays
            }
            
            // Event info at bottom
            EventInfoView(
                title: event.title,
                location: event.location,
                description: event.description,
                showFullEventInfo: $showFullEventInfo
            )
        }
        .frame(width: SizeConstants.width, height: SizeConstants.height)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .offset(x: xOffset)
        .rotationEffect(.degrees(degrees))
        .animation(
            reduceMotion ? .none : .snappy,
            value: xOffset
        )
        .gesture(swipeGesture)
        .fullScreenCover(isPresented: $showFullEventInfo) {
            eventDetailView
        }
        .alert("Error", isPresented: $showErrorAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
        .onReceive(eventModel.$buttonSwipeAction) { action in
            handleSwipeAction(action)
        }
        .onAppear {
            Self.logger.debug("CardView appeared for event: \(event.id)")
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Event card: \(event.title)")
        .accessibilityHint("Double tap to view details, swipe left to pass, swipe right to like")
        .accessibilityAction(.magicTap) {
            showFullEventInfo = true
        }
    }
    
    // MARK: - View Components
    @ViewBuilder
    private var eventImage: some View {
        KFImage(URL(string: currentImageURL))
            .placeholder {
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.gray.opacity(0.3))
                    .overlay {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                    }
            }
            .retry(maxCount: 3)
            .onFailure { error in
                Self.logger.error("Failed to load image: \(error.localizedDescription)")
                showError("Failed to load event image")
            }
            .resizable()
            .aspectRatio(
                CGSize(width: SizeConstants.width, height: SizeConstants.height),
                contentMode: .fill
            )
            .accessibilityLabel("Event image \(currentImageIndex + 1) of \(imageCount)")
    }
    
    @ViewBuilder
    private var imageOverlays: some View {
        VStack {
            // Image navigation overlay (only if multiple images)
            if hasMultipleImages {
                ImageScrollingOverlayView(
                    currentImageIndex: $currentImageIndex,
                    totalImageCount: imageCount - 1
                )
            }
            
            Spacer()
            
            // Image indicators
            if hasMultipleImages {
                CardImageIndicatorView(
                    currentIndex: currentImageIndex,
                    totalImageCount: imageCount
                )
                .padding()
            }
            
            // Swipe action indicators
            SwipeActionIndicatorView(xOffset: $xOffset)
        }
    }
    
    @ViewBuilder
    private var eventDetailView: some View {
        NavigationStack {
            EventScreenView(
                handleNavigation: true,
                systemImageName: "xmark"
            ) { direction in
                if direction != .forward {
                    eventModel.clearCurrentEventDetails()
                    showFullEventInfo = false
                }
            }
            .accessibilityAddTraits(.isModal)
        }
        .onAppear {
            eventModel.setCurrentEventDetails(event)
        }
    }
    
    private var swipeGesture: some Gesture {
        DragGesture()
            .onChanged(handleDragChanged)
            .onEnded(handleDragEnded)
    }
}

// MARK: - Private Methods
private extension CardView {
    func showError(_ message: String) {
        errorMessage = message
        showErrorAlert = true
        Self.logger.error("CardView error: \(message)")
    }
    
    func returnToCenter() {
        withAnimation(reduceMotion ? .none : .easeOut) {
            xOffset = 0
            degrees = 0
        }
    }
    
    func swipeLeft() {
        guard !isProcessingAction else { return }
        isProcessingAction = true
        
        let animation = reduceMotion ? .none : .easeIn(duration: 0.3)
        
        withAnimation(animation) {
            xOffset = -500
            degrees = -12
        } completion: {
            handleSwipeCompletion(action: .reject)
        }
    }
    
    func swipeRight() {
        guard !isProcessingAction else { return }
        isProcessingAction = true
        
        let animation = reduceMotion ? .none : .easeIn(duration: 0.3)
        
        withAnimation(animation) {
            xOffset = 500
            degrees = 12
        } completion: {
            handleSwipeCompletion(action: .like)
        }
    }
    
    func handleSwipeCompletion(action: Action) {
        Task { @MainActor in
            defer {
                eventModel.buttonSwipeAction = nil
                isProcessingAction = false
            }
            
            guard let uid = authenticationModel.state.currentUser?.id else {
                showError("User not authenticated")
                return
            }
            
            do {
                switch action {
                case .like:
                    alert = "right"
                    try await eventModel.likeEvent(event, userID: uid)
                    
                    // Add haptic feedback for success
                    let feedback = UINotificationFeedbackGenerator()
                    feedback.notificationOccurred(.success)
                    
                    Self.logger.info("Event liked successfully: \(event.id)")
                    
                case .reject:
                    alert = "left"
                    // Note: Assuming there's a dislike method in EventModel
                    interactionModel.dislikeEvent(userId: uid, eventId: event.id.uuidString)
                    
                    Self.logger.info("Event disliked: \(event.id)")
                    
                case .refresh:
                    await eventModel.fetchEventFeed(uid: uid)
                    Self.logger.debug("Event feed refreshed")
                }
                
                // Remove from feed after successful action
                if action != .refresh {
                    eventModel.removeEventFromFeed(event)
                }
                
            } catch {
                showError("Failed to process action: \(error.localizedDescription)")
                returnToCenter() // Return card to center on error
            }
        }
    }
    
    func handleSwipeAction(_ action: Action?) {
        guard let action = action else { return }
        
        // Only process if this is the top card
        let topCard = eventModel.events.last
        guard topCard?.id == event.id else { return }
        
        switch action {
        case .like:
            swipeRight()
        case .reject:
            swipeLeft()
        case .refresh:
            Task {
                guard let uid = authenticationModel.state.currentUser?.id else { return }
                await eventModel.fetchEventFeed(uid: uid)
            }
        }
    }
}

// MARK: - Gesture Handlers
private extension CardView {
    func handleDragChanged(_ value: DragGesture.Value) {
        guard !isProcessingAction else { return }
        
        xOffset = value.translation.width
        degrees = Double(value.translation.width / 25)
    }
    
    func handleDragEnded(_ value: DragGesture.Value) {
        guard !isProcessingAction else { return }
        
        let width = value.translation.width
        
        if abs(width) < abs(swipeThreshold) {
            returnToCenter()
            return
        }
        
        if width >= swipeThreshold {
            swipeRight()
        } else {
            swipeLeft()
        }
    }
}

// MARK: - Preview
#Preview {
    let sampleEvent = try! Event(
        id: UUID(),
        title: "Sample Event",
        description: "This is a sample event description",
        date: "2024-12-25",
        timeRange: "7:00 PM - 11:00 PM",
        location: "Sample Location",
        category: .music,
        createdBy: "sample-user-id"
    )
    
    return CardView(event: sampleEvent, alert: .constant(""))
        .environmentObject(AuthenticationModel(authenticationService: MockAuthenticationService(), state: AppState()))
        .environmentObject(EventModel(service: MockEventService()))
        .environmentObject(UserProfileModel.mockUserProfileModel)
        .environmentObject(InteractionModel(service: MockInteractionService()))
}

// Mock service for preview
struct MockInteractionService: InteractionService {
    func likeEvent(userId: String, eventId: String) {}
    func dislikeEvent(userId: String, eventId: String) {}
}
