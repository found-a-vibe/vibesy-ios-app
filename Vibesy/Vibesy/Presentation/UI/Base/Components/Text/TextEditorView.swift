//
//  TextFieldView.swift
//  Found A Vibe
//
//  Created by Alexander Cleoni on 10/04/24.
//

import SwiftUI

struct TextEditorView: View {
    @Binding var input: String
    let placeholder: String
    let maxCharacters: Int = 150

    @State private var internalInput: String = ""

    var body: some View {
        ZStack(alignment: .topLeading) {
            TextEditor(text: $input)
                .padding(.leading, 45)
                .frame(maxHeight: 100)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.gray, lineWidth: 1)
                )
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 8))

            Image(systemName: "flame.fill")
                .resizable()
                .scaledToFit()
                .frame(width: 24, height: 24)
                .padding(.leading, 16)
                .padding(.top, 8)

            if input.isEmpty {
                Text(placeholder)
                    .foregroundColor(Color(.systemGray3))
                    .padding(.leading, 48)
                    .padding(.top, 10)
            }
        }
        .onChange(of: input) {oldValue, newValue in
            if newValue.count > maxCharacters {
                input = String(newValue.prefix(maxCharacters))
            }
        }
    }
}

#Preview {
    TextEditorView(input: .constant(""), placeholder: "Describe your vibe")
        .padding()
}
