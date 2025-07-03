//
//  FirebaseEventImageManager.swift
//  Vibesy
//
//  Created by Alexander Cleoni on 12/19/24.
//

import FirebaseStorage
import SwiftUI

struct FirebaseEventImageManager {
    private let storage = Storage.storage()
    
    func uploadSingleImage(
        _ image: UIImage,
        folder: String,
        id: UUID,
        index: Int,
        storageRef: StorageReference = Storage.storage().reference()
    ) async throws -> String {
        guard let data = image.jpegData(compressionQuality: 0.8) else {
            throw NSError(
                domain: "ImageConversion",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Failed to convert image to JPEG"]
            )
        }
        let path = "\(folder)/\(id.uuidString.lowercased())/image_\(index).jpg"
        let ref = storageRef.child(path)
        let meta = StorageMetadata()
        meta.contentType = "image/jpeg"

        // Upload
        _ = try await ref.putDataAsync(data, metadata: meta)
        // Get download URL
        let url = try await ref.downloadURL()
        return url.absoluteString
    }

    func uploadImages(
        _ images: [UIImage],
        folder: String,
        id: UUID,
        completion: @escaping ([String]) -> Void
    ) {
        let dispatchGroup = DispatchGroup()
        var uploadedImageURLs = [String]()
        let barrierQueue = DispatchQueue(label: "image.upload.queue", attributes: .concurrent)

        for (index, image) in images.enumerated() {
            dispatchGroup.enter()
            // fire off each upload in its own Task so we can await the async function
            Task {
                do {
                    let urlString = try await uploadSingleImage(
                        image,
                        folder: folder,
                        id: id,
                        index: index
                    )
                    // append in a thread-safe way
                    barrierQueue.async(flags: .barrier) {
                        uploadedImageURLs.append(urlString)
                        dispatchGroup.leave()
                    }
                } catch {
                    print("Failed to upload image \(index): \(error)")
                    dispatchGroup.leave()
                }
            }
        }

        dispatchGroup.notify(queue: .main) {
            print("All uploads complete: \(uploadedImageURLs.count) images uploaded.")
            completion(uploadedImageURLs)
        }
    }
    
    
    // Delete all images associated with an event
    func deleteImages(eventId: String, completion: @escaping (Result<Void, Error>) -> Void) {
        let storageRef = storage.reference()
        let eventImagesRef = storageRef.child("event_images/\(eventId.lowercased())")
        
        let dispatchGroup = DispatchGroup()
        var deletionErrors = [Error]()
        let errorQueue = DispatchQueue(label: "image.deletion.queue", attributes: .concurrent)

        // Fetch all image references for the event
        eventImagesRef.listAll { result, error in
            if let error = error {
                print("Error retrieving images for event \(eventId): \(error.localizedDescription)")
                completion(.failure(error))
                return
            }
            
            guard let result else { return }
            
            guard !result.items.isEmpty else {
                print("No images found for event \(eventId). Nothing to delete.")
                completion(.success(()))
                return
            }

            print("Deleting \(result.items.count) images for event \(eventId)...")

            // Delete all images concurrently
            result.items.forEach { imageRef in
                dispatchGroup.enter()
                imageRef.delete { error in
                    if let error = error {
                        errorQueue.async(flags: .barrier) {
                            deletionErrors.append(error)
                        }
                        print("Failed to delete \(imageRef.fullPath): \(error.localizedDescription)")
                    } else {
                        print("Deleted \(imageRef.fullPath)")
                    }
                    dispatchGroup.leave()
                }
            }

            // Completion handler after all deletions finish
            dispatchGroup.notify(queue: .main) {
                if deletionErrors.isEmpty {
                    print("All images for event \(eventId) deleted successfully.")
                    completion(.success(()))
                } else {
                    let aggregatedError = NSError(domain: "ImageDeletion", code: 500, userInfo: [
                        NSLocalizedDescriptionKey: "Some images failed to delete. See logs for details."
                    ])
                    print("Some images failed to delete.")
                    completion(.failure(aggregatedError))
                }
            }
        }
    }
    
    func retrieveImagesForEventIds(eventIds: [String], completion: @escaping ([String: [String]]) -> Void) {
        let dispatchGroup = DispatchGroup()
        var imagesDict = [String: [String]]()
        
        // Helper function to fetch images for an event
        func fetchEventImages(eventId: String) {
            dispatchGroup.enter()
            retrieveEventImages(eventId: eventId) { imageURLs in
                DispatchQueue.main.async {
                    imagesDict[eventId] = imageURLs
                }
                dispatchGroup.leave()
            }
        }

        // Iterate through event IDs and fetch images
        for eventId in eventIds {
            fetchEventImages(eventId: eventId)
        }

        // Notify when all image retrievals are complete
        dispatchGroup.notify(queue: .main) {
            print("Completed retrieving images for all events.")
            completion(imagesDict)
        }
    }

    func retrieveEventImages(eventId: String, completion: @escaping ([String]) -> Void) {
        let storageRef = storage.reference()
        let eventImagesPath = "event_images/\(eventId.lowercased())"
        let eventImagesRef = storageRef.child(eventImagesPath)

        eventImagesRef.listAll { result, error in
            if let error = error {
                print("Error retrieving images for event \(eventId): \(error.localizedDescription)")
                completion([])
                return
            }
            
            guard let result = result, !result.items.isEmpty else {
                print("No images found for event \(eventId).")
                completion([])
                return
            }

            let dispatchGroup = DispatchGroup()
            var imageURLs: [String] = []
            
            // Fetch image URLs
            for item in result.items {
                dispatchGroup.enter()
                item.downloadURL { url, error in
                    if let url = url {
                        DispatchQueue.main.async {
                            imageURLs.append(url.absoluteString)
                        }
                        print("Retrieved image URL: \(url.absoluteString)")
                    } else {
                        print("Failed to retrieve URL: \(error?.localizedDescription ?? "Unknown error")")
                    }
                    dispatchGroup.leave()
                }
            }

            // Notify when all image retrievals are complete
            dispatchGroup.notify(queue: .main) {
                print("Completed image retrieval for event \(eventId). \(imageURLs.count) images found.")
                completion(imageURLs)
            }
        }
    }
}
