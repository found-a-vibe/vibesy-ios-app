//
//  SignInView.swift
//  Vibesy
//
//  Created by Alexander Cleoni on 12/15/24.
//

import SwiftUI

struct SignUpView: View {
    @EnvironmentObject var authenticationModel: AuthenticationModel
    @EnvironmentObject var userProfileModel: UserProfileModel
    
    @EnvironmentObject var homePageCoordinator: HomePageCoordinator
    
    @FocusState private var emailFieldIsFocused: Bool
    
    @State private var isSecure = true
    
    @State private var selectedURL: IdentifiedURL?
    @State private var showWebView = false
    
    @State private var userDoesAgreeToTerms = false
    
    @Binding var isSignIn: Bool
    
    private func handleSubmit() {
        authenticationModel.signUp()
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
                            Text("Sign Up")
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
                            .padding(.bottom)
                            
                            HStack(spacing: 0) {
                                Toggle(isOn: $userDoesAgreeToTerms) {
                                    
                                }
                                .toggleStyle(iOSCheckboxToggleStyle())
                                .onChange(of: userDoesAgreeToTerms) { _, newValue in

                                }
                                .padding(.trailing, 10)
                                
                                Text("I agree to the ")
                                    .fixedSize(horizontal: false, vertical: true)
                                
                                Button(action: {
                                    selectedURL = IdentifiedURL(string: "https://found-a-vibe.github.io/vibesy-legal/eula.pdf")
                                    showWebView = true
                                }) {
                                    Text("EULA")
                                        .foregroundColor(.espresso)
                                        .underline()
                                }
                                
                                Text(" and")
                                
                                Button(action: {
                                    selectedURL = IdentifiedURL(string: "https://found-a-vibe.github.io/vibesy-legal/privacy_policy.pdf")
                                    showWebView = true
                                }) {
                                    Text(" Privacy Policy")
                                        .foregroundColor(.espresso)
                                        .underline()
                                }
                                
                                Text(".")
                            }
                            .fixedSize(horizontal: false, vertical: true)
                            Button(
                                action: {
                                    handleSubmit()
                                },
                                label: {
                                    Text("Sign Up")
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
                            .disabled(!userDoesAgreeToTerms)
                            
                            HStack {
                                Text("Already have an account?")
                                Button(action: {
                                    isSignIn.toggle()
                                }) {
                                    Text("Log In")
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
        }
        .sheet(item: $selectedURL) { item in
            WebView(url: item.url)
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
                        .foregroundStyle(.espresso)
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
    SignUpView(isSignIn: .constant(true))
        .environmentObject(AuthenticationModel(authenticationService: FirebaseAuthenticationService(), state: AppState()))
}
