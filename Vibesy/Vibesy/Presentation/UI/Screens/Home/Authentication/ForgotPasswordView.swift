//
//  ForgotPasswordView.swift
//  FoundAVibe
//
//  Created by Alexander Cleoni on 10/10/24.
//

import SwiftUI

struct ForgotPasswordView: View {
    @EnvironmentObject var homePageCoordinator: HomePageCoordinator
    
    @EnvironmentObject var userPasswordModel: UserPasswordModel
    
    @FocusState private var emailFieldIsFocused: Bool
    
    @State var input: String = ""
    @State var errorMessage: String = ""
    @State private var showAlert = false
    
    func handleSubmit() {
        userPasswordModel.sendOTP(for: input) { result in
            if let status = try? result.get().status, status == "OK" {
                homePageCoordinator.push(page: .otpVerificationView)
            } else if let response = try? result.get() {
                self.errorMessage = response.description
                self.showAlert.toggle()
            } else {
                self.errorMessage = "Unexpected error sending OTP to \(input)."
                self.showAlert.toggle()
            }
        }
    }
    
    var body: some View {
        VStack {
            VStack(spacing: 12) {
                Text("Reset Password")
                    .font(.abeezeeItalic(size: 26))
                    .lineSpacing(6)
                    .frame(width: 236, height: 60)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white)
            }
            .padding(.vertical)
            .frame(maxWidth: .infinity, alignment: .leading)
            
            VStack(alignment: .leading, spacing: 16) {
                Text("Forgot Password?")
                    .font(.abeezeeItalic(size: 26))
                    .frame(maxWidth: .infinity, maxHeight: 43, alignment: .leading)
                    .padding(.top)
                
                Text("Enter the email address associated with your account")
                    .font(.abeezee(size: 14))
                    .opacity(0.8)
                    .frame(maxWidth: 280, maxHeight: 43)
                Text("We will send you a one-time passcode to reset your password")
                    .font(.abeezee(size: 14))
                    .frame(maxWidth: 293, maxHeight: 43)
                TextFieldView(
                    input: $input, keyboardType: .emailAddress,
                    iconName: "envelope.fill",
                    placeholder: "info@youremail.com"
                )
                .textInputAutocapitalization(.never)
                .disableAutocorrection(true)
                .focused($emailFieldIsFocused)
                
                Button(
                    action: {
                        handleSubmit()
                    },
                    label: {
                        Text("Send One-Time Passcode")
                            .font(.custom("ABeeZee-Italic", size: 20))
                            .frame(maxWidth: .infinity, maxHeight: 51)
                            .foregroundStyle(.white)
                    }
                )
                .alert(isPresented: $showAlert) {
                    Alert(
                        title: Text("An error has occured"),
                        message: Text(errorMessage),
                        dismissButton: .default(Text("OK"))
                    )
                }
                .frame(maxHeight: 51)
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.roundedRectangle(radius: 8))
                .tint(.sandstone)
                Button(
                    action: {
                        homePageCoordinator.popToRoot()
                    },
                    label: {
                        Text("Cancel")
                            .font(.custom("ABeeZee-Italic", size: 18))
                            .frame(maxWidth: .infinity, maxHeight: 51)
                            .foregroundStyle(.espresso)
                    }
                )
                .buttonStyle(.borderless)
                .tint(.espresso)
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
        .onTapGesture {
            hideKeyboard()
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
    ForgotPasswordView()
}
