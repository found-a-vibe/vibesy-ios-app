//
//  ActionButtonView.swift
//  FoundAVibe
//
//  Created by Alexander Cleoni on 10/25/24.
//

import SwiftUI

enum Action {
    case like
    case refresh
    case reject
}

struct ActionButtonView: View {
    @EnvironmentObject var eventModel: EventModel
    
    var body: some View {
        HStack(spacing: 48) {
            Button {
                eventModel.buttonSwipeAction = .reject
            } label: {
                Text("👎")
                    .background {
                        Circle()
                            .fill(Color.white)
                            .frame(width: 48, height: 48)
                            .shadow(radius: 5)
                    }
            }
            .buttonStyle(.plain)
            
            Button {
                eventModel.buttonSwipeAction = .refresh
            } label: {
                Image("Refresh")
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 24, height: 24)
                    .foregroundStyle(.goldenBrown)
                    .background {
                        Circle()
                            .fill(Color.white)
                            .frame(width: 48, height: 48)
                            .shadow(radius: 5)
                    }
                
            }
            .buttonStyle(.plain)
            
            Button {
                print("It's A Vibe")
                eventModel.buttonSwipeAction = .like
            } label: {
                Text("👍")
                    .background {
                        Circle()
                            .fill(Color.white)
                            .frame(width: 48, height: 48)
                            .shadow(radius: 5)
                    }
            }
            .buttonStyle(.plain)
        }
    }
}

#Preview {
    ActionButtonView()
}
