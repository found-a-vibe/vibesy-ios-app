//
//  FlagContentView.swift
//  Vibesy
//
//  Created by Alexander Cleoni on 8/28/25.
//

import SwiftUI

import SwiftUI

struct FlagContentView: View {
    @State private var selectedReason: String? = nil
    @State private var customReason: String = ""
    @State private var showConfirmation = false
    
    @Binding var showFlagContentView: Bool
    
    var removeContent: (() -> Void)
    
    
    let reasons = [
        "Nudity or Sexual Content",
        "Hate Speech or Symbols",
        "Violence or Threats",
        "Spam or Scam",
        "False Information",
        "Other"
    ]
    
    var body: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Why are you flagging this content?")
                    .font(.headline)
                
                ForEach(reasons, id: \.self) { reason in
                    HStack {
                        Image(systemName: selectedReason == reason ? "largecircle.fill.circle" : "circle")
                            .foregroundColor(.espresso)
                        Text(reason)
                        Spacer()
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        selectedReason = reason
                    }
                }
                
                if selectedReason == "Other" {
                    
                    TextFieldView(
                        input: $customReason, keyboardType: .default,
                        iconName: nil,
                        placeholder: "Please specify"
                    )
                    .textInputAutocapitalization(.never)
                    .disableAutocorrection(true)
                }
                
                Spacer()
                
                Button(action: {
                    showConfirmation = true
                    // Example: print selected reason
                    let finalReason = selectedReason == "Other" ? customReason : selectedReason ?? ""
                    print("Flag submitted for reason: \(finalReason)")
                }) {
                    Text("Submit")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(isSubmitEnabled ? Color.espresso : Color.gray)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                }
                .disabled(!isSubmitEnabled)
                .padding(.top)
                
                .alert(isPresented: $showConfirmation) {
                    Alert(
                        title: Text("Thank You"),
                        message: Text("Your report has been submitted."),
                        dismissButton: .default(Text("OK"), action: {
                            showFlagContentView.toggle()
                            removeContent()
                        }),
                    )
                }
            }
            .padding()
            .navigationTitle("Flag Content")
        }
    }
    
    var isSubmitEnabled: Bool {
        guard let reason = selectedReason else { return false }
        if reason == "Other" {
            return !customReason.trimmingCharacters(in: .whitespaces).isEmpty
        }
        return true
    }
}

#Preview {
    FlagContentView(showFlagContentView: .constant(true)) {
        
    }
}
