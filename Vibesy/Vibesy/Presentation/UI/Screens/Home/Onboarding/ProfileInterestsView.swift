//
//  ProfileInterestsView.swift
//  Vibesy
//
//  Created by Alexander Cleoni on 12/15/24.
//

import SwiftUI

struct ProfileInterestsView: View {
    @EnvironmentObject var userProfileModel: UserProfileModel
    @EnvironmentObject var onboardingPageCoordinator: OnboardingPageCoordinator

    @State private var tags: [String] = []
    
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
                            TagField(tags: $tags, placeholder: "Add Interests...")
                                .accentColor(.espresso)
                                .styled(.RoundedBorder)
                                .lowercase(false)
                            Button(
                                action: {
                                    tags.forEach {
                                        userProfileModel.userProfile.interests.append($0)
                                    }
                                    onboardingPageCoordinator.push(page: .profileImagePickerView)
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
    ProfileInterestsView()
}
