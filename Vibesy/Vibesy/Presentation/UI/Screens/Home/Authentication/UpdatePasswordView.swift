//
//  UpdatePassword.swift
//  FoundAVibe
//
//  Created by Alexander Cleoni on 10/11/24.
//

import SwiftUI

struct UpdatePasswordView: View {
    @EnvironmentObject var homePageCoordinator: HomePageCoordinator
    @EnvironmentObject var userPasswordModel: UserPasswordModel
    @EnvironmentObject var authenticationModel: AuthenticationModel

    @State var input: String = ""
    @State var goNext: Bool = false
    @State var isSecure: Bool = true
    
    @FocusState private var emailFieldIsFocused: Bool
    
    @State private var errorMessage: String = ""
    
    @State private var showAlert: Bool = false
    
    private func handleSubmit() {
        userPasswordModel.updatePassword(withNewPassword: input) { result in
            if let status = try? result.get().status, status == "OK" {
                if let email = userPasswordModel.email {
                    authenticationModel.email = email
                    authenticationModel.password = input
                    authenticationModel.signIn()
                }
            } else if let response = try? result.get() {
                self.errorMessage = response.description
                self.showAlert.toggle()
            } else {
                self.errorMessage = "Unexpected error updating your password."
                self.showAlert.toggle()
            }
        }
    }
    
    var body: some View {
        VStack {
            VStack(spacing: 12) {
                Text("New Password")
                    .font(.abeezeeItalic(size: 26))
                    .lineSpacing(6)
                    .frame(width: 236, height: 60)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white)
            }
            .padding(.vertical)
            .frame(maxWidth: .infinity, alignment: .leading)
            
            VStack(spacing: 16) {
                Text("Create New Password")
                    .font(.abeezeeItalic(size: 26))
                    .frame(maxWidth: .infinity, maxHeight: 43, alignment: .leading)
                    .padding(.top)
                
                Text("You have successfully verified your email address.")
                    .font(.abeezee(size: 14))
                    .multilineTextAlignment(.leading)
                    .opacity(0.8)
                    .frame(maxWidth: .infinity, maxHeight: 43, alignment: .leading)
                Text("Please create your new password")
                    .font(.abeezee(size: 14))
                    .frame(maxWidth: .infinity, maxHeight: 43, alignment: .leading)
                TextFieldView(
                    input: $input, isSecure: $isSecure,
                    keyboardType: .default, iconName: "lock.fill",
                    placeholder: "password"
                )
                .overlay(alignment: .trailing) {
                    Image(systemName: isSecure ? "eye.slash" : "eye")
                        .resizable()
                        .frame(width: 20, height: 16)
                        .onTapGesture {
                            isSecure.toggle()
                        }
                        .padding()
                }
                .textInputAutocapitalization(.never)
                .disableAutocorrection(true)
                .focused($emailFieldIsFocused)
                
                Button(
                    action: {
                        handleSubmit()
                    },
                    label: {
                        Text("Continue")
                            .font(.custom("ABeeZee-Italic", size: 20))
                            .frame(maxWidth: .infinity, maxHeight: 51)
                            .foregroundStyle(.white)
                    }
                )
                .alert(isPresented: $showAlert) {
                    Alert(
                        title: Text("An error has occured."),
                        message: Text(errorMessage),
                        dismissButton: .default(Text("OK"))
                    )
                }
                .disabled(input.count < 6)
                .frame(maxHeight: 51)
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.roundedRectangle(radius: 8))
                .tint(.sandstone)
                .padding(.vertical)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .padding()
            .background(.white)
            .clipShape(
                .rect(
                    topLeadingRadius: 60,
                    bottomLeadingRadius: 0,
                    bottomTrailingRadius: 0,
                    topTrailingRadius: 60
                )
            )
            .edgesIgnoringSafeArea(.bottom)
        }
        .background(
            LinearGradient(
                gradient: Gradient(colors: [
                    .sandstone,
                    .goldenBrown,
                    .espresso
                ]), startPoint: .topLeading, endPoint: .bottomTrailing
            )
        )
        .onAppear {
            emailFieldIsFocused = true
        }
        .gesture(
            DragGesture().onChanged { _ in
                hideKeyboard()
            }
        )
        .scrollDismissesKeyboard(.interactively)
        .ignoresSafeArea(.keyboard)
        .navigationBarBackButtonHidden()
        
    }
    
}

#Preview {
    UpdatePasswordView()
}
