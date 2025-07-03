//
//  ProfileImagePickerView.swift
//  FoundAVibe
//
//  Created by Alexander Cleoni on 10/4/24.
//

import SwiftUI

struct ProfileImagePickerView: View {
    @EnvironmentObject var authenticationModel: AuthenticationModel
    @EnvironmentObject var userProfileModel: UserProfileModel
    @EnvironmentObject var onboardingPageCoordinator: OnboardingPageCoordinator
    
    @State private var isImagePickerPresented = false
    @State private var sourceType: UIImagePickerController.SourceType = .photoLibrary
    @State private var showingSourceOptions = false
    @State private var selectedImage: UIImage?
    
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
                                    .foregroundStyle(.white)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                Text("Please enter your details")
                                    .font(.abeezee(size: 12))
                                    .foregroundStyle(.white)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .padding(.vertical)
                            Rectangle()
                                .fill(.white)
                                .stroke(
                                    Color.gray, // Change the color as needed
                                    style: StrokeStyle(lineWidth: 4, dash: [10, 5]) // Change lineWidth and dash pattern as needed
                                )
                                .frame(maxWidth: 175, maxHeight: 175)
                                .padding()
                                .overlay(alignment: .center) {
                                    VStack {
                                        if let image = selectedImage {
                                            Image(uiImage: image)
                                                .resizable()
                                                .aspectRatio(CGSize(width: 1, height: 1), contentMode: .fill)
                                                .frame(width: 175, height: 175)                                    .onTapGesture {
                                                    showingSourceOptions.toggle()
                                                }
                                        } else {
                                            VStack(spacing: 18) {
                                                Image(systemName: "plus")
                                                    .resizable()
                                                    .scaledToFit()
                                                    .frame(maxWidth: 34, maxHeight: 34)
                                                Text("Upload")
                                                    .font(.custom("ABeeZee-Italic", size: 16))
                                            }
                                            .onTapGesture {
                                                showingSourceOptions.toggle()
                                            }
                                        }
                                    }
                                    .frame(maxWidth: 175, maxHeight: 175)
                                }
                            Button(
                                action: {
                                    if let current = authenticationModel.state.currentUser {
                                        if let image = selectedImage {
                                            userProfileModel.updateUserProfile(userId: current.id, image: image)
                                        } else {
                                            userProfileModel.updateUserProfile(userId: current.id, image: nil)
                                        }
                                        
                                        var updated = current
                                        updated.isNewUser = false
                                        authenticationModel.state.currentUser = updated
                                    }
                                    
                                },
                                label: {
                                    Text("Save")
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
        .sheet(isPresented: $isImagePickerPresented) {
            ImagePicker(image: $selectedImage, sourceType: sourceType)
        }
        .confirmationDialog("Edit Profile Picture", isPresented: $showingSourceOptions, titleVisibility: .visible) {
            Button("Choose from library") {
                sourceType = .photoLibrary
                isImagePickerPresented.toggle()
            }
            Button("Take photo") {
                sourceType = .camera
                isImagePickerPresented.toggle()
            }
        }
        .edgesIgnoringSafeArea(.bottom)
        .ignoresSafeArea(.keyboard)
    }
}

#Preview {
    ProfileImagePickerView()
}


