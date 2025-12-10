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
            Task { @MainActor in
                if let status = try? result.get().status, status == "OK" {
                    homePageCoordinator.push(page: .otpVerificationView)
                } else if let response = try? result.get() {
                    self.errorMessage = response.description
                    self.showAlert.toggle()
                } else {
                    self.errorMessage =
                        "Unexpected error sending OTP to \(input)."
                    self.showAlert.toggle()
                }
            }
        }
    }

    var body: some View {
        ZStack(alignment: .top) {
            VStack(spacing: 12) {
                Image("VibesyTitle")
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: 220)
                VStack {
                    VStack(alignment: .leading) {
                        Text("Forgot Password?")
                            .font(.aBeeZeeRegular(size: 26))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity, maxHeight: 43, alignment: .leading)
                            .padding(.top)
                        
                        Text("Enter the email address associated with your account")
                            .font(.aBeeZeeRegular(size: 14))
                            .foregroundStyle(.white)
                            .frame(maxHeight: 43)
                        Text("We will send you a one-time passcode to reset your password")
                            .font(.aBeeZeeRegular(size: 14))
                            .foregroundStyle(.white)
                            .frame(maxHeight: 43)
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
                        .tint(.goldenBrown)
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
                        .frame(maxHeight: .infinity, alignment: .top)

                    }
                    .padding()
                }

            }
            .background(
                LinearGradient(
                    gradient: Gradient(
                        colors: [.espresso, .goldenBrown]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
        }
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
        .edgesIgnoringSafeArea(.bottom)
        .scrollDismissesKeyboard(.interactively)
        .ignoresSafeArea(.keyboard)
        .navigationBarBackButtonHidden()

    }
}

#Preview {
    ForgotPasswordView()
}
