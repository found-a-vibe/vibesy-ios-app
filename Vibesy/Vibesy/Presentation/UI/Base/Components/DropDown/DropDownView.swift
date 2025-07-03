//
//  DropDownView.swift
//  FoundAVibe
//
//  Created by Alexander Cleoni on 10/4/24.
//

import SwiftUI

struct DropDownView: View {
    @State private var isExpanded: Bool = false
    @Binding var selectedOption: String
    let options = ["He/Him", "She/Her", "They/Them"]
    
    var body: some View {
        DisclosureGroup(selectedOption, isExpanded: $isExpanded) {
            VStack {
                ForEach(options, id: \.self) { option in
                    Text(option)
                        .padding()
                        .onTapGesture {
                            selectedOption = option
                            isExpanded = false
                        }
                }
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 8)
            .fill(.white)
            .stroke(Color.gray, lineWidth: 1))
        .cornerRadius(8)
    }
}
#Preview {
    DropDownView(selectedOption: .constant("Select an Option"))
}
