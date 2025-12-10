//
//  OnboardingView.swift
//  Vibesy
//
//  Created by Alexander Cleoni  on 12/8/25.
//

import SwiftUI

enum Field {
    case one, two
}

struct OnboardingView: View {
    @EnvironmentObject var authenticationModel: AuthenticationModel
    @EnvironmentObject var userProfileModel: UserProfileModel

    @FocusState private var focusedField: Field?

    @State private var input: String = ""
    @State private var selection: String = "Select your Pronouns"
    @State private var tags: [String] = []
    @State private var isImagePickerPresented = false
    @State private var sourceType: UIImagePickerController.SourceType =
        .photoLibrary
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
                    .font(.aBeeZeeRegular(size: 14))
                    .lineSpacing(6)
                    .frame(width: 236, height: 40)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white)
                ScrollView {
                    VStack(spacing: 12) {
                        VStack(spacing: 8) {
                            Text("Complete Your Profile")
                                .font(.aBeeZeeRegular(size: 26))
                                .foregroundStyle(.goldenBrown)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            Text("Please enter your details")
                                .font(.aBeeZeeRegular(size: 12))
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(.vertical)

                        // Profile Image
                        VStack {
                            Rectangle()
                                .fill(.white)
                                .stroke(
                                    Color.gray,  // Change the color as needed
                                    style: StrokeStyle(
                                        lineWidth: 4,
                                        dash: [10, 5]
                                    )  // Change lineWidth and dash pattern as needed
                                )
                                .frame(width: 175, height: 175)
                                .padding()
                                .overlay(alignment: .center) {
                                    VStack {
                                        if let image = selectedImage {
                                            Image(uiImage: image)
                                                .resizable()
                                                .aspectRatio(
                                                    CGSize(width: 1, height: 1),
                                                    contentMode: .fill
                                                )
                                                .frame(width: 175, height: 175)
                                                .onTapGesture {
                                                    showingSourceOptions.toggle()
                                                }
                                        } else {
                                            VStack(spacing: 18) {
                                                Image(systemName: "plus")
                                                    .resizable()
                                                    .scaledToFit()
                                                    .frame(
                                                        maxWidth: 34,
                                                        maxHeight: 34
                                                    )
                                                Text("Upload")
                                                    .font(
                                                        .custom(
                                                            "ABeeZee-Italic",
                                                            size: 16
                                                        )
                                                    )
                                            }
                                            .onTapGesture {
                                                showingSourceOptions.toggle()
                                            }
                                        }
                                    }
                                    .frame(width: 175, height: 175)
                                }
                        }

                        // Full Name
                        TextFieldView(
                            input: $userProfileModel.userProfile.fullName,
                            keyboardType: .default,
                            iconName: "person.fill",
                            placeholder: "Full Name"
                        )
                        .focused($focusedField, equals: .one)
                        .textInputAutocapitalization(.never)
                        .disableAutocorrection(true)

                        // Age
                        TextFieldView(
                            input: $userProfileModel.userProfile.age,
                            keyboardType: .numberPad,
                            iconName: "clock.fill",
                            placeholder: "Enter Age"
                        )
                        .textInputAutocapitalization(.never)
                        .disableAutocorrection(true)

                        // Pronouns
                        DropDownView(selectedOption: $selection)

                        // Interests
                        TagField(tags: $tags, placeholder: "Add Interests...")
                            .accentColor(.espresso)
                            .styled(.RoundedBorder)
                            .lowercase(false)

                        // Bio Description
                        TextEditorView(
                            input: $input,
                            placeholder: "Describe Your Vibe"
                        )
                        .focused($focusedField, equals: .two)

                        // Submit
                        Button(
                            action: {
                                if let current = authenticationModel.state
                                    .currentUser
                                {
                                    // Update Pronouns
                                    userProfileModel.userProfile.updatePronouns(
                                        selection == "Select your Pronouns"
                                            ? "N/A" : selection
                                    )

                                    // Update Interests
                                    tags.forEach {
                                        userProfileModel.userProfile.interests
                                            .append($0)

                                    }
                                    // Update bio
                                    userProfileModel.userProfile.bio = input

                                    if let image = selectedImage {
                                        userProfileModel.updateUserProfile(
                                            userId: current.id,
                                            image: image
                                        )
                                    } else {
                                        userProfileModel.updateUserProfile(
                                            userId: current.id,
                                            image: nil
                                        )
                                    }

                                    var updated = current
                                    updated.isNewUser = false
                                    authenticationModel.state.currentUser =
                                        updated
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
                    }
                    .padding()
                }
            }
            .sheet(isPresented: $isImagePickerPresented) {
                ImagePicker(image: $selectedImage, sourceType: sourceType)
            }
            .confirmationDialog(
                "Edit Profile Picture",
                isPresented: $showingSourceOptions,
                titleVisibility: .visible
            ) {
                Button("Choose from library") {
                    sourceType = .photoLibrary
                    isImagePickerPresented.toggle()
                }
                Button("Take photo") {
                    sourceType = .camera
                    isImagePickerPresented.toggle()
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
    }
}
