//
//  LikedEventsView.swift
//  Vibesy
//
//  Created by Alexander Cleoni on 3/6/25.
//

import SwiftUI

struct LikedEventsView: View {
    @EnvironmentObject var pageCoordinator: LikedEventPageCoordinator
    @EnvironmentObject var userProfileModel: UserProfileModel
    var body: some View {
        EventListView(eventsHeaderViewText: "Liked Events", showEventCardIcon: true, eventsByStatus: .likedEvents, profileImageUrl: "") { direction in
            if direction == .forward {
                pageCoordinator.push(page: .likedEventDetails)
            }
        }
    }
}

#Preview {
    LikedEventsView()
}
