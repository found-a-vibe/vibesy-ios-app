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
    
    @State private var rememberMe: Bool = UserDefaults.standard.bool(forKey: "rememberMe")
    
    @Binding var isSignIn: Bool
    
    private func handleSubmit() {
        authenticationModel.signIn()
    }
    
    /// Save `rememberMe` to UserDefaults and trigger action if true
    private func setRememberMe(_ value: Bool) {
        UserDefaults.standard.set(value, forKey: "rememberMe") // Save to UserDefaults
    }
    
    var body: some View {
        ZStack(alignment: .top) {
            VStack(spacing: 12) {
                Image("VibesyTitle")
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: 220)
                Text("Find Local Events And People To Vibe With In Realtime")
                    .font(.abeezeeItalic(size: 14))
                    .lineSpacing(6)
                    .frame(width: 236, height: 40)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white)
                    Spacer()
            }
            .frame(
                maxWidth: .infinity,
                maxHeight: UIScreen.main.bounds.height <= 568 ? 150 : 240
                )
            .background (
                LinearGradient(
                    gradient: Gradient(
                        colors: [.sandstone, .goldenBrown, .espresso ]),
                    startPoint: .topLeading, endPoint: .bottomTrailing
                )
            )
            VStack {
                Spacer(minLength: UIScreen.main.bounds.height <= 568 ? 150 : 180)
                
                Color.white
                .clipShape(
                    .rect(
                        topLeadingRadius: 60,
                        bottomLeadingRadius: 0,
                        bottomTrailingRadius: 0,
                        topTrailingRadius: 60
                    )
                )
                .overlay {
                    VStack {
                        Text("Login")
                            .font(.abeezee(size: 26))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .foregroundStyle(.espresso)
                            .padding(.vertical)
                        TextFieldView(
                            input: $authenticationModel.email, keyboardType: .emailAddress,
                            iconName: "envelope.fill",
                            placeholder: "info@youremail.com"
                        )
                        .textInputAutocapitalization(.never)
                        .disableAutocorrection(true)
                        .focused($emailFieldIsFocused)
                        TextFieldView(
                            input: $authenticationModel.password, isSecure: $isSecure,
                            keyboardType: .default, iconName: "lock.fill",
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
                            }
                            .toggleStyle(iOSCheckboxToggleStyle())
                            .onChange(of: rememberMe) { _, newValue in
                                setRememberMe(newValue)
                            }
                            Spacer()
                            Button(action: {
                                homePageCoordinator.push(page: .forgotPasswordView)
                            }) {
                                Text("Forgot Password?")
                                    .font(.custom("ABeeZee-Italic", size: 12))
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(.sandstone)
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
                        
                        //                    HStack {
                        //                        Divider().frame(width: 50, height: 1).background(.white)
                        //                        Text("Or Continue With")
                        //                            .font(.custom("ABeeZee-Regular", size: 16))
                        //                            .foregroundStyle(.white)
                        //                        Divider().frame(width: 50, height: 1).background(.white)
                        //                    }
                        //                    .frame(maxWidth: .infinity, alignment: .center)
                        //                    .padding(.vertical)
                        //                    HStack(spacing: 16) {
                        //                        Image("SIWFB")
                        //                        Image("SIWA")
                        //                        Image("SIWG")
                        //                    }
                        HStack {
                            Text("Don't have and account?")
                            Button(action: {
                                isSignIn.toggle()
                            }) {
                                Text("Sign Up")
                                    .foregroundStyle(.sandstone)
                                    .underline()
                            }
                        }
                        .buttonStyle(.plain)
                        .frame(maxHeight: .infinity, alignment: .center)
                    }
                    .padding()
                }
            }
        }
        .overlay(alignment: .center) {
            if authenticationModel.authError != nil {
                RoundedRectangle(cornerRadius: 20)
                    .fill(
                        LinearGradient (colors: [.sandstone, .goldenBrown, .espresso], startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                    .frame(maxWidth: 393, maxHeight: 155)
                    .padding()
                    .overlay {
                        VStack(alignment: .center, spacing: 12) {
                            Text("An error has occured!")
                                .font(.abeezeeItalic(size: 20))
                            Text(authenticationModel.authError!)
                                .font(.abeezeeItalic(size: 14))
                                .multilineTextAlignment(.center)
                            Button(action: {authenticationModel.authError = nil}) {
                                Text("Try Again")
                                    .font(.headline)
                                    .frame(maxWidth: .infinity, alignment: .center)
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
        .environmentObject(AuthenticationModel(authenticationService: FirebaseAuthenticationService(), state: AppState()))
}
