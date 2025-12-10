//
//  SignInView.swift
//  Vibesy
//
//  Created by Alexander Cleoni on 12/15/24.
//

import SwiftUI

struct SignInView: View {
    @EnvironmentObject var authenticationModel: AuthenticationModel
    @EnvironmentObject var userProfileModel: UserProfileModel

    @EnvironmentObject var homePageCoordinator: HomePageCoordinator

    @FocusState private var emailFieldIsFocused: Bool

    @State private var isSecure = true

    @State private var rememberMe: Bool = UserDefaults.standard.bool(
        forKey: "rememberMe"
    )

    @Binding var isSignIn: Bool

    private func handleSubmit() {
        authenticationModel.signIn()
    }

    /// Save `rememberMe` to UserDefaults and trigger action if true
    private func setRememberMe(_ value: Bool) {
        UserDefaults.standard.set(value, forKey: "rememberMe")  // Save to UserDefaults
    }

    var body: some View {
        ZStack(alignment: .top) {
            VStack(spacing: 12) {
                Image("VibesyTitle")
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: 220)
                Text("Find Local Events And People To Vibe With In Realtime")
                    .font(.aBeeZeeRegular(size: 12))
                    .lineSpacing(6)
                    .frame(width: 236, height: 40)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white)
                VStack {
                    VStack {
                        Text("Login")
                            .font(.aBeeZeeRegular(size: 14))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .foregroundStyle(.white)
                            .padding(.vertical)
                        TextFieldView(
                            input: $authenticationModel.email,
                            keyboardType: .emailAddress,
                            iconName: "envelope.fill",
                            placeholder: "info@youremail.com"
                        )
                        .textInputAutocapitalization(.never)
                        .disableAutocorrection(true)
                        .focused($emailFieldIsFocused)
                        TextFieldView(
                            input: $authenticationModel.password,
                            isSecure: $isSecure,
                            keyboardType: .default,
                            iconName: "lock.fill",
                            placeholder: "password"
                        )
                        .textInputAutocapitalization(.never)
                        .disableAutocorrection(true)
                        .overlay(alignment: .trailing) {
                            Image(systemName: isSecure ? "eye.slash" : "eye")
                                .resizable()
                                .frame(width: 20, height: 16)
                                .onTapGesture {
                                    isSecure.toggle()
                                }
                                .padding()
                        }
                        HStack {
                            Toggle(isOn: $rememberMe) {
                                Text("Remember Me")
                                    .font(.custom("ABeeZee-Regular", size: 12))
                                    .foregroundStyle(.white)
                            }
                            .foregroundStyle(.white)
                            .toggleStyle(iOSCheckboxToggleStyle())
                            .onChange(of: rememberMe) { _, newValue in
                                setRememberMe(newValue)
                            }
                            Spacer()
                            Button(action: {
                                homePageCoordinator.push(
                                    page: .forgotPasswordView
                                )
                            }) {
                                Text("Forgot Password?")
                                    .font(.custom("ABeeZee-Italic", size: 12))
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(.white)
                        }
                        .padding(.vertical, 6)
                        Button(
                            action: {
                                handleSubmit()
                            },
                            label: {
                                Text("Login")
                                    .font(.custom("ABeeZee-Italic", size: 20))
                                    .frame(maxWidth: .infinity, maxHeight: 51)
                                    .foregroundStyle(.white)
                            }
                        )
                        .frame(height: 51)
                        .buttonStyle(.borderedProminent)
                        .buttonBorderShape(.roundedRectangle(radius: 8))
                        .tint(.espresso)
                        .padding(.vertical)

                        HStack {
                            Text("Don't have and account?")
                                .foregroundStyle(.white)
                            Button(action: {
                                isSignIn.toggle()
                            }) {
                                Text("Sign Up")
                                    .foregroundStyle(.espresso)
                                    .underline()
                            }
                        }
                        .buttonStyle(.plain)
                        .frame(maxHeight: .infinity, alignment: .center)
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
        .overlay(alignment: .center) {
            if authenticationModel.authError != nil {
                RoundedRectangle(cornerRadius: 20)
                    .fill(
                        LinearGradient(
                            colors: [.espresso, .goldenBrown],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(maxWidth: 393, maxHeight: 155)
                    .padding()
                    .overlay {
                        VStack(alignment: .center, spacing: 12) {
                            Text("An error has occured!")
                                .font(.aBeeZeeRegular(size: 20))
                            Text(authenticationModel.authError!)
                                .font(.aBeeZeeRegular(size: 14))
                                .multilineTextAlignment(.center)
                            Button(action: {
                                authenticationModel.authError = nil
                            }) {
                                Text("Try Again")
                                    .font(.headline)
                                    .frame(
                                        maxWidth: .infinity,
                                        alignment: .center
                                    )
                                    .padding(.vertical)
                            }
                        }
                        .foregroundStyle(.white)
                        .padding()
                    }
                    .animation(.easeInOut)
            }
        }
        .edgesIgnoringSafeArea(.bottom)
        .ignoresSafeArea(.keyboard)
        .navigationBarBackButtonHidden()
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
    }
}

#Preview {
    SignInView(isSignIn: .constant(true))
        .environmentObject(
            AuthenticationModel(
                authenticationService: FirebaseAuthenticationService(),
                state: AppState()
            )
        )
}
