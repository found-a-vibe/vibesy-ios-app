//
//  ProfileDetailsView.swift
//  Vibesy
//
//  Created by Alexander Cleoni on 12/18/24.
//

import SwiftUI
import Kingfisher
import WrappingHStack

fileprivate struct LocalImageStore {
    @MainActor static let shared = LocalImageStore()
    private let fileManager = FileManager.default
    private let imagesDirectoryName = "ProfileImages"
    private let filenamesKey = "profile_image_filenames"

    private var imagesDirectoryURL: URL? {
        do {
            let docs = try fileManager.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            let dir = docs.appendingPathComponent(imagesDirectoryName, isDirectory: true)
            if !fileManager.fileExists(atPath: dir.path) {
                try fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
            }
            return dir
        } catch {
            return nil
        }
    }

    // Persist a new image and return its filename
    func saveImage(_ image: UIImage) -> String? {
        guard let dir = imagesDirectoryURL else { return nil }
        let filename = UUID().uuidString + ".jpg"
        let url = dir.appendingPathComponent(filename)
        guard let data = image.jpegData(compressionQuality: 0.9) else { return nil }
        do {
            try data.write(to: url, options: .atomic)
            var names = loadFilenames()
            names.append(filename)
            storeFilenames(names)
            return filename
        } catch {
            return nil
        }
    }

    // Delete an image by filename
    func deleteImage(filename: String) {
        guard let dir = imagesDirectoryURL else { return }
        let url = dir.appendingPathComponent(filename)
        do {
            if fileManager.fileExists(atPath: url.path) {
                try fileManager.removeItem(at: url)
            }
            var names = loadFilenames()
            if let idx = names.firstIndex(of: filename) {
                names.remove(at: idx)
                storeFilenames(names)
            }
        } catch {
            // ignore
        }
    }

    // Load a UIImage for a filename
    func loadImage(filename: String) -> UIImage? {
        guard let dir = imagesDirectoryURL else { return nil }
        let url = dir.appendingPathComponent(filename)
        guard let data = try? Data(contentsOf: url), let img = UIImage(data: data) else { return nil }
        return img
    }

    // MARK: - Filenames persistence
    func loadFilenames() -> [String] {
        (UserDefaults.standard.array(forKey: filenamesKey) as? [String]) ?? []
    }

    private func storeFilenames(_ names: [String]) {
        UserDefaults.standard.set(names, forKey: filenamesKey)
    }
}

struct ProfileDetailsView: View {
    @EnvironmentObject var authenticationModel: AuthenticationModel
    @EnvironmentObject var userProfileModel: UserProfileModel
    @EnvironmentObject var friendshipModel: FriendshipModel
    
    @State private var profilePhotos: [UIImage] = []
    @State private var isImagePickerPresented = false
    @State private var sourceType: UIImagePickerController.SourceType = .photoLibrary
    @State private var showingSourceOptions = false
    @State private var selectedImage: UIImage?
    @State private var storedFilenames: [String] = []
    
    var navigate: ((_ direction: Direction) -> Void)? = nil
    
    var body: some View {
        VStack {
            HStack {
                BackButtonView(color: .goldenBrown) {
                    if let navigate {
                        navigate(.back)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                Text("Profile")
                    .font(.aBeeZeeRegular(size: 24))
                    .foregroundStyle(.goldenBrown)
                    .padding(.trailing)
                    .frame(maxWidth: .infinity, alignment: .center)
                Spacer()
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            // Profile details
            VStack(spacing: 16) {
                HStack(spacing: 16) {
                    // Profile image
                    VStack {
                        if userProfileModel.userProfile.profileImageUrl != "" {
                            KFImage(URL(string: userProfileModel.userProfile.profileImageUrl))
                                .resizable()
                                .scaledToFill()
                                .frame(width: 144, height: 144)
                                .clipped()
                                .cornerRadius(12)
                                .shadow(radius: 5)
                        } else {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(.goldenBrown.opacity(0.3))
                                .frame(width: 149, height: 144)
                                .overlay(alignment: .bottom) {
                                    Image(systemName: "person.fill")
                                        .resizable()
                                        .scaledToFit()
                                        .foregroundStyle(.goldenBrown)
                                        .frame(width: 114.5, height: 112)
                                }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    
                    
                    VStack(alignment: .leading, spacing: 10) {
                        // Name and details
                        Text("Name: \(userProfileModel.userProfile.fullName)")
                            .font(.aBeeZeeRegular(size: 14))
                        Text("Age : \(userProfileModel.userProfile.age)")
                            .font(.aBeeZeeRegular(size: 14))
                        Text("Pronouns: \(userProfileModel.userProfile.pronouns)")
                            .font(.aBeeZeeRegular(size: 14))
                        
                        Button(action: {
                            // Edit Profile action
                            if let navigate {
                                navigate(.forward)
                            }
                        }) {
                            Text("Edit Profile")
                                .font(.aBeeZeeRegular(size: 12))
                                .foregroundColor(.white)
                                .frame(maxWidth: 124, maxHeight: 28)
                                .padding(2)
                                .background(.goldenBrown)
                                .cornerRadius(8)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                
                // "My Vibe" section
                VStack(alignment: .leading, spacing: 8) {
                    Text("My Vibe")
                        .font(.aBeeZeeRegular(size: 16))
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text(userProfileModel.userProfile.bio)
                        .font(.aBeeZeeRegular(size: 14))
                        .multilineTextAlignment(.leading)
                        .foregroundStyle(.black.opacity(0.6))
                }
                .padding(.vertical)
                
                // Interests section
                VStack(alignment: .leading, spacing: 8) {
                    Text("Interests")
                        .font(.aBeeZeeRegular(size: 16))
                        .frame(maxWidth: .infinity, alignment: .leading)
                    WrappingHStack(userProfileModel.userProfile.interests) { interest in
                        ProfileTagView(text: interest)
                            .padding(.vertical, 8)
                    }
                }
                .padding(.vertical)
                
                // Photo Grid section
                VStack(alignment: .leading, spacing: 12) {
                    Text("Photos")
                        .font(.aBeeZeeRegular(size: 16))
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    if profilePhotos.isEmpty {
                        // Empty state
                        VStack(spacing: 12) {
                            Image(systemName: "photo.on.rectangle.angled")
                                .font(.system(size: 40))
                                .foregroundColor(.goldenBrown.opacity(0.6))
                            Text("Upload your first photo")
                                .font(.aBeeZeeRegular(size: 14))
                                .foregroundColor(.black)
                            Button(action: {
                                showingSourceOptions = true
                            }) {
                                Label("Add Photo", systemImage: "plus.circle.fill")
                                    .font(.aBeeZeeRegular(size: 12))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 20)
                                    .padding(.vertical, 10)
                                    .background(.goldenBrown)
                                    .cornerRadius(8)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 200)
                        .background(Color.goldenBrown.opacity(0.1))
                        .cornerRadius(12)
                    } else {
                        // Photo grid
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                            ForEach(0..<profilePhotos.count, id: \.self) { index in
                                Image(uiImage: profilePhotos[index])
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: (UIScreen.main.bounds.width - 48) / 3, height: (UIScreen.main.bounds.width - 48) / 3)
                                    .clipped()
                                    .cornerRadius(8)
                                    .overlay(alignment: .topTrailing) {
                                        Button(action: {
                                            // Remove image in memory
                                            profilePhotos.remove(at: index)
                                            // Remove persisted file if we have a matching filename
                                            if index < storedFilenames.count {
                                                let filename = storedFilenames.remove(at: index)
                                                LocalImageStore.shared.deleteImage(filename: filename)
                                            }
                                        }) {
                                            Image(systemName: "xmark.circle.fill")
                                                .foregroundColor(.white)
                                                .background(Circle().fill(Color.black.opacity(0.6)))
                                                .padding(4)
                                        }
                                    }
                            }
                            
                            // Add photo button
                            if profilePhotos.count < 9 {
                                Button(action: {
                                    showingSourceOptions = true
                                }) {
                                    VStack(spacing: 8) {
                                        Image(systemName: "plus")
                                            .font(.system(size: 24))
                                        Text("Add")
                                            .font(.aBeeZeeRegular(size: 10))
                                    }
                                    .foregroundColor(.goldenBrown)
                                    .frame(width: (UIScreen.main.bounds.width - 48) / 3, height: (UIScreen.main.bounds.width - 48) / 3)
                                    .background(Color.goldenBrown.opacity(0.1))
                                    .cornerRadius(8)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(Color.goldenBrown, style: StrokeStyle(lineWidth: 2, dash: [5]))
                                    )
                                }
                            }
                        }
                    }
                }
                .padding(.vertical)
            }
            Spacer()
        }
        .padding()
        .onAppear {
            // Load filenames and images from disk
            let names = LocalImageStore.shared.loadFilenames()
            storedFilenames = names
            profilePhotos = names.compactMap { LocalImageStore.shared.loadImage(filename: $0) }
        }
        .confirmationDialog("Add Photo", isPresented: $showingSourceOptions, titleVisibility: .visible) {
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
        .onChange(of: selectedImage) { _, newImage in
            if let newImage = newImage {
                // Save to disk
                if let filename = LocalImageStore.shared.saveImage(newImage) {
                    storedFilenames.append(filename)
                }
                // Update in-memory grid
                profilePhotos.append(newImage)
                selectedImage = nil
            }
        }
    }
}

// Reusable tag view
struct ProfileTagView: View {
    var text: String
    
    var body: some View {
        Text("\(text)")
            .font(.aBeeZeeRegular(size: 12))
            .foregroundColor(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.goldenBrown)
            .cornerRadius(12)
    }
}

#Preview {
    let userProfileModel = UserProfileModel.mockUserProfileModel
    
    ProfileDetailsView()
        .environmentObject(userProfileModel)
}

