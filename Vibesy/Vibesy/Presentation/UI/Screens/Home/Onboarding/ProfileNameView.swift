//
//  ProfileNameView.swift
//  FoundAVibe
//
//  Created by Alexander Cleoni on 10/4/24.
//

import SwiftUI

struct ProfileNameView: View {
    @EnvironmentObject var userProfileModel: UserProfileModel
    @EnvironmentObject var onboardingPageCoordinator: OnboardingPageCoordinator
    @FocusState private var focusedField: Field?
    
    @State private var input: String = ""
    
    enum Field {
        case one, two
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
                            VStack(spacing: 8) {
                                Text("Complete Your Profile")
                                    .font(.abeezee(size: 26))
                                    .foregroundStyle(.espresso)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                Text("Please enter your details")
                                    .font(.abeezee(size: 12))
                                    .foregroundStyle(.white)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .padding(.vertical)
                            TextFieldView(
                                input: $userProfileModel.userProfile.fullName, keyboardType: .default,
                                iconName: "person.fill",
                                placeholder: "Full Name"
                            )
                            .focused($focusedField, equals: .one)
                            .textInputAutocapitalization(.never)
                            .disableAutocorrection(true)
                            TextEditorView(input: $input, placeholder: "Describe Your Vibe")
                                .focused($focusedField, equals: .two)
                                .frame(maxHeight: 90)
                            Button(
                                action: {
                                    userProfileModel.userProfile.bio = input
                                    onboardingPageCoordinator.push(page: .profileAgeView)
                                },
                                label: {
                                    Text("Next")
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
                            Spacer()
                        }
                        .padding()
                    }
            }
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
        .ignoresSafeArea(.keyboard)
    }
}

#Preview {
    ProfileNameView()
        .environmentObject(UserProfileModel(userProfileService: FirebaseUserProfileService()))
}
