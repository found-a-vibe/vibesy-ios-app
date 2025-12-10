//
//  EventScreenImageView.swift
//  Vibesy
//
//  Created by Alexander Cleoni on 3/6/25.
//

import Kingfisher
import SwiftUI

struct EventScreenImageView: View {
    @EnvironmentObject var eventModel: EventModel
    
    let eventImage: String?
    let eventIsLiked: Bool
    let eventIsReserved: Bool
    let enableAdminMode: Bool
    let isUserGenerated: Bool
    let interactWithEvent: () -> Void
    
    var body: some View {
        ZStack(alignment: .bottomLeading) {
            KFImage(URL(string: eventImage ?? ""))
                .resizable()
                .aspectRatio(contentMode: isUserGenerated ? .fill : .fit)
                .frame(height: 200)
                .clipped()
        }
        .frame(height: 200)
    }
}
