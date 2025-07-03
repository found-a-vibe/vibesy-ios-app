//
//  EventInfoView.swift
//  FoundAVibe
//
//  Created by Alexander Cleoni on 10/21/24.
//

import SwiftUI

struct EventInfoView: View {
    var title: String = ""
    var location: String = ""
    var description: String = ""
    
    @Binding var showFullEventInfo: Bool
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                        .font(.abeezeeItalic(size: 22))
                        .foregroundStyle(.sandstone)
                Text(location)
                        .font(.abeezeeItalic(size: 18))
                        .foregroundStyle(.espresso)
                Text(description)
                        .font(.abeezeeItalic(size: 14))
            }
            .padding()
            .background(.white.opacity(0.8))
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .frame(maxWidth: .infinity, alignment: .leading)
            
            Button {
                showFullEventInfo.toggle()
            } label: {
                Image(systemName: "arrow.up.circle")
                    .fontWeight(.bold)
                    .imageScale(.large)
                    .foregroundStyle(.white)
                
            }
        }
        .padding()
        .background(
            LinearGradient(colors: [.clear, .black], startPoint: .top, endPoint: .bottom)
        )
    }
}

#Preview {
    EventInfoView(showFullEventInfo: .constant(false))
}
