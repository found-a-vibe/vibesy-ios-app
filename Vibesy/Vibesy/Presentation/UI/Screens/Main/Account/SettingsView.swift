//
//  AccountSettingsView.swift
//  Vibesy
//
//  Created by Alexander Cleoni on 8/1/25.
//

import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var authenticationModel: AuthenticationModel
    
    @State private var currentPassword = ""
    @State private var newPassword = ""
    @State private var confirmNewPassword = ""
    
    @State private var deletePassword = ""
            
    var navigate: ((_ direction: Direction) -> Void)? = nil
    
    private var allFieldsFilled: Bool {
        !currentPassword.isEmpty && !newPassword.isEmpty && !confirmNewPassword.isEmpty
    }
    
    var body: some View {
        VStack {
            HStack {
                BackButtonView(color: .goldenBrown) {
                    if let navigate {
                        navigate(.back)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Text("Settings")
                    .font(.aBeeZeeRegular(size: 24))
                    .foregroundStyle(.goldenBrown)
                    .frame(maxWidth: .infinity, alignment: .center)
                Spacer()
                    .frame(maxWidth: .infinity, alignment: .trailing)
                
            }
            
            VStack(spacing: 24) {
                // Password Section
                SectionBox(title: "Password") {
                    TextFieldView(
                        input: $currentPassword, isSecure: .constant(true),
                        keyboardType: .default,
                        placeholder: "Current Password"
                    )
                    
                    TextFieldView(
                        input: $newPassword, isSecure: .constant(true),
                        keyboardType: .default,
                        placeholder: "New Password"
                    )
                    
                    TextFieldView(
                        input: $confirmNewPassword, isSecure: .constant(true),
                        keyboardType: .default,
                        placeholder: "Confirm New Password"
                    )
                    
                    Button(action: {
                        if newPassword != confirmNewPassword {
                            newPassword = ""
                            confirmNewPassword = ""
                            authenticationModel.activeAlert = .passwordMismatch
                        } else {
                            // Handle password update
                            if let user = authenticationModel.state.currentUser {
                                authenticationModel.updateCurrentUserPassword(email: user.email, password: currentPassword, newPassword: newPassword)
                                currentPassword = ""
                                newPassword = ""
                                confirmNewPassword = ""
                            }
                        }
                        
                    }) {
                        Label("Update Password", systemImage: "lock.fill")
                            .frame(maxWidth: .infinity, maxHeight: 51)
                    }
                    .disabled(!allFieldsFilled)
                    .frame(height: 51)
                    .buttonStyle(.borderedProminent)
                    .tint(.green)
                }
                
                // Delete Account Section
                SectionBox(title: "Delete Account") {
                    Text("Account deletion is non-reversible. Please proceed with caution.")
                        .font(.footnote)
                        .foregroundColor(.gray)
                    
                    TextFieldView(
                        input: $deletePassword, isSecure: .constant(true),
                        keyboardType: .default,
                        placeholder: "Confirm Password"
                    )
                    
                    Button(action: {
                        // Handle account deletion
                        if let user = authenticationModel.state.currentUser {
                            authenticationModel.deleteCurrentUser(email: user.email, password: deletePassword)
                        }
                    }) {
                        Label("Delete Account", systemImage: "trash.fill")
                            .frame(maxWidth: .infinity, maxHeight: 51)
                    }
                    .disabled(deletePassword.isEmpty)
                    .frame(height: 51)
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
                }
            }
            .frame(maxHeight: .infinity, alignment: .topLeading)
        }
        .padding()
        .alert(item: $authenticationModel.activeAlert) { alert in
            Alert(
                title: Text(alert.title),
                message: Text(alert.message),
                dismissButton: .default(Text("OK"))
            )
        }
        
    }
}

// MARK: - Section Box Component

struct SectionBox<Content: View>: View {
    var title: String
    var content: () -> Content
    
    init(title: String, @ViewBuilder content: @escaping () -> Content) {
        self.title = title
        self.content = content
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
                .bold()
            content()
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
}

#Preview {
    SettingsView()
}
