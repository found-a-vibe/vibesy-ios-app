//
//  ProfileDetailsEditView.swift
//  Vibesy
//
//  Created by Alexander Cleoni on 12/26/24.
//

import SwiftUI
import Kingfisher

struct ProfileDetailsEditView: View {
    @EnvironmentObject var authenticationModel: AuthenticationModel
    @EnvironmentObject var userProfileModel: UserProfileModel
    
    @State private var tags: [String] = []
    @State private var selection = "Select your Pronouns"
    @State private var isImagePickerPresented = false
    @State private var sourceType: UIImagePickerController.SourceType = .photoLibrary
    @State private var showingSourceOptions = false
    @State private var selectedImage: UIImage?
    
    @FocusState private var focusedField: Field?
    
    var navigate: ((_ direction: Direction) -> Void)? = nil
    
    enum Field {
        case one, two, three
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                HStack {
                    BackButtonView {
                        if let navigate {
                            navigate(.back)
                        }
                        if let user = authenticationModel.state.currentUser {
                            userProfileModel.userProfile.updatePronouns(selection == "Select your Pronouns" ? "N/A" : selection)
                            userProfileModel.userProfile.interests.removeAll()
                            tags.forEach {
                                if $0 != "" {
                                    userProfileModel.userProfile.interests.append($0)
                                }
                            }
                            userProfileModel.updateUserProfile(userId: user.id, image: selectedImage ?? nil)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    Text("Edit Profile")
                        .font(.abeezeeItalic(size: 24))
                        .foregroundStyle(.espresso)
                        .frame(maxWidth: .infinity, alignment: .center)
                    Spacer()
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
                // Profile image
                VStack {
                    if let selectedImage {
                        Image(uiImage: selectedImage)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 144, height: 144)
                            .clipped()
                            .cornerRadius(12)
                            .shadow(radius: 5)
                            .overlay(alignment: .bottomTrailing) {
                                Image("Editing")
                                    .renderingMode(.template)
                                    .resizable()
                                    .frame(width: 28, height: 28)
                                    .padding(4)
                                    .foregroundStyle(.white)
                            }
                    } else if userProfileModel.userProfile.profileImageUrl != "" {
                        KFImage(URL(string: userProfileModel.userProfile.profileImageUrl))
                            .resizable()
                            .scaledToFill()
                            .frame(width: 144, height: 144)
                            .clipped()
                            .cornerRadius(12)
                            .shadow(radius: 5)
                            .overlay(alignment: .bottomTrailing) {
                                Image("Editing")
                                    .renderingMode(.template)
                                    .resizable()
                                    .frame(width: 28, height: 28)
                                    .padding(4)
                                    .foregroundStyle(.white)
                            }
                    } else {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(.sandstone.opacity(0.3))
                            .frame(width: 149, height: 144)
                            .overlay(alignment: .bottom) {
                                Image(systemName: "person.fill")
                                    .resizable()
                                    .scaledToFit()
                                    .foregroundStyle(.sandstone)
                                    .frame(width: 114.5, height: 112)
                            }
                            .overlay(alignment: .bottomTrailing) {
                                Image("Editing")
                                    .renderingMode(.template)
                                    .resizable()
                                    .frame(width: 28, height: 28)
                                    .padding(4)
                                    .foregroundStyle(.espresso)
                            }
                    }
                }
                .onTapGesture {
                    showingSourceOptions.toggle()
                }
                .frame(maxWidth: .infinity, alignment: .center)
                VStack {
                    Text("Full Name")
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .font(.poppins(size: 12))
                    TextFieldView(
                        input: $userProfileModel.userProfile.fullName, keyboardType: .default,
                        iconName: "person.fill",
                        placeholder: "Full Name"
                    )
                    .focused($focusedField, equals: .one)
                    .textInputAutocapitalization(.never)
                    .disableAutocorrection(true)
                }
                VStack {
                    Text("Age")
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .font(.poppins(size: 12))
                    TextFieldView(
                        input: $userProfileModel.userProfile.age, keyboardType: .numberPad,
                        iconName: "clock.fill",
                        placeholder: "Enter Age"
                    )
                    .focused($focusedField, equals: .two)
                    .textInputAutocapitalization(.never)
                    .disableAutocorrection(true)
                }
                VStack {
                    Text("Pronouns")
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .font(.poppins(size: 12))
                    DropDownView(selectedOption: $selection)
                }
                VStack {
                    Text("Interests")
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .font(.poppins(size: 12))
                    TagField(tags: $tags, placeholder: "Add Interests...")
                        .accentColor(.espresso)
                        .styled(.RoundedBorder)
                        .lowercase(false)
                }
                VStack {
                    Text("Describe Your Vibe")
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .font(.poppins(size: 12))
                    TextEditorView(input: $userProfileModel.userProfile.bio, placeholder: "Describe Your Vibe")
                        .focused($focusedField, equals: .three)
                        .frame(height: 90)
                }
            }
            .padding()
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
            .sheet(isPresented: $isImagePickerPresented) {
                ImagePicker(image: $selectedImage, sourceType: sourceType)
            }
            .onAppear {
                userProfileModel.userProfile.interests.forEach {
                    tags.append($0)
                }
                selection = userProfileModel.userProfile.pronouns
            }
            .onTapGesture {
                hideKeyboard()
            }
        }
    }
}

#Preview {
    ProfileDetailsEditView()
        .environmentObject(UserProfileModel(userProfileService: FirebaseUserProfileService()))
}
