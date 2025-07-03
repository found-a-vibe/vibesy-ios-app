//
//  CardStackView.swift
//  FoundAVibe
//
//  Created by Alexander Cleoni on 10/25/24.
//

import SwiftUI

struct CardStackView: View {
    @EnvironmentObject var eventModel: EventModel
    @EnvironmentObject var userProfileModel: UserProfileModel
    @EnvironmentObject var authenticationModel: AuthenticationModel
    
    @State private var alert = ""
        
    func reloadData() {
        if let uid = authenticationModel.state.currentUser?.id {
            eventModel.fetchEventFeed(uid: uid)
        }
    }
    
    var body: some View {
        VStack {
            if eventModel.events.count > 0 {
                ZStack {
                    ForEach(eventModel.events) { event in
                        CardView(event: event, alert: $alert)
                    }
                }
                ActionButtonView()
            } else {
                NoCardView() {
                    reloadData()
                }
            }
        }
        .overlay(alignment: .center) {
            if alert != "" && alert == "right" {
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
                            Image(systemName: "multiply")
                                .position(x: 325, y: 50)
                                .fontWeight(.semibold)
                                .onTapGesture {
                                    alert = ""
                                }
                            VStack(spacing: 12) {
                                Text("It's A Vibe!")
                                    .font(.abeezeeItalic(size: 20))
                                Text("This Vibe has been added to your liked\nevents, keep swiping for more")
                                    .font(.abeezeeItalic(size: 14))
                                    .multilineTextAlignment(.center)
                            }
                        }
                        .foregroundStyle(.white)
                    }
                    .animation(.easeInOut)
            }
            
            if alert != "" && alert == "left" {
                RoundedRectangle(cornerRadius: 20)
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                .espresso,
                                .sandstone,
                            ]), startPoint: .top, endPoint: .bottom
                        )
                    )
                    .frame(maxWidth: 393, maxHeight: 155)
                    .padding()
                    .overlay {
                        ZStack {
                            Image(systemName: "multiply")
                                .position(x: 325, y: 50)
                                .fontWeight(.semibold)
                                .onTapGesture {
                                    alert = ""
                                }
                            VStack(spacing: 12) {
                                Text("Not A Vibe!")
                                    .font(.abeezeeItalic(size: 20))
                                Text("Keep swiping to find a vibe.")
                                    .font(.abeezeeItalic(size: 14))
                                    .multilineTextAlignment(.center)
                            }
                        }
                        .foregroundStyle(.white)
                    }
                    .animation(.easeInOut)
            }
            
        }
    }
}

#Preview {
    CardStackView()
}
