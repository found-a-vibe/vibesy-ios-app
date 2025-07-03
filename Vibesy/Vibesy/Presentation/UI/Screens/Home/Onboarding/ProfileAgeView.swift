//
//  ProfileAgeView.swift
//  FoundAVibe
//
//  Created by Alexander Cleoni on 10/4/24.
//

import SwiftUI

struct ProfileAgeView: View {
    @EnvironmentObject var userProfileModel: UserProfileModel
    @EnvironmentObject var onboardingPageCoordinator: OnboardingPageCoordinator
    @FocusState private var focusedField: Field?
    
    @State var selection: String = "Select your Pronouns"
    
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
                            input: $userProfileModel.userProfile.age, keyboardType: .numberPad,
                            iconName: "clock.fill",
                            placeholder: "Enter Age"
                        )
                        .textInputAutocapitalization(.never)
                        .disableAutocorrection(true)
                        DropDownView(selectedOption: $selection)
                        Button(
                            action: {
                                userProfileModel.userProfile.pronouns = selection == "Select your Pronouns" ? "N/A" : selection
                                onboardingPageCoordinator.push(page: .profileInterestsView)
                            },
                            label: {
                                Text("Next")
                                    .font(.abeezeeItalic(size: 20))
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
    ProfileAgeView()
        .environmentObject(UserProfileModel(userProfileService: FirebaseUserProfileService()))
}
