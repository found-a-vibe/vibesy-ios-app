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
    
    // MARK: - Leaf: static so it doesn't capture `self`
    static func uploadSingleImage(
        data: Data,
        folder: String,
        id: UUID,
        index: Int
    ) async throws -> String {
        let filename = "\(id.uuidString.lowercased())_\(index).jpg"
        // create a fresh ref per upload; no shared state captured
        let fileRef = Storage.storage().reference().child(folder).child(filename)
        
        _ = try await fileRef.putDataAsync(data, metadata: nil)
        let url = try await fileRef.downloadURL()
        return url.absoluteString
    }
    
    // MARK: - Guest Image Upload
    static func uploadGuestImage(
        image: UIImage,
        eventId: UUID,
        guestId: UUID
    ) async throws -> String {
        // Precompute Data on main to avoid moving UIImage across executors
        struct JPEGError: LocalizedError { var errorDescription: String? { "Could not make JPEG" } }
        let imageData = try await MainActor.run {
            guard let data = image.jpegData(compressionQuality: 0.9) else { throw JPEGError() }
            return data
        }
        
        let folder = "guest_images/\(eventId.uuidString.lowercased())"
        
        return try await uploadSingleImage(
            data: imageData,
            folder: folder,
            id: guestId,
            index: 0
        )
    }
    
    // MARK: - Bulk
    static func uploadImages(images: [UIImage], folder: String, id: UUID) async throws -> [String] {
        // Precompute Data on main so we don't move UIImage across executors
        struct JPEGError: LocalizedError { var errorDescription: String? { "Could not make JPEG" } }
        let payloads: [(index: Int, data: Data)] = try await MainActor.run {
            try images.enumerated().map { (i, img) in
                guard let d = img.jpegData(compressionQuality: 0.9) else { throw JPEGError() }
                return (i, d)
            }
        }
        
        return try await withThrowingTaskGroup(of: (Int, String).self) { group in
            for (i, data) in payloads {
                group.addTask {
                    let url = try await Self.uploadSingleImage(
                        data: data, folder: folder, id: id, index: i
                    )
                    return (i, url)
                }
            }
            
            var byIndex: [Int: String] = [:]
            for try await (i, url) in group { byIndex[i] = url }
            return (0..<images.count).compactMap { byIndex[$0] }
        }
    }
    
    // Delete all images associated with an event
    static func deleteImages(eventId: String, completion: @escaping (Result<Void, Error>) -> Void) {
        let storageRef = Storage.storage().reference()
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
    
    // MARK: - Completion wrappers (no Sendable warnings)
    static func retrieveImagesForEventIds(
        eventIds: [String],
        completion: @escaping @MainActor ([String: [String]]) -> Void
    ) {
        Task.detached { [eventIds] in                    // don't capture `self`
            let dict = (try? await Self.retrieveImagesForEventIds(eventIds)) ?? [:]
            await completion(dict)                       // closure is MainActor-isolated
        }
    }
    
    static func retrieveEventImages(
        eventId: String,
        completion: @escaping @MainActor ([String]) -> Void
    ) {
        Task.detached { [eventId] in                     // don't capture `self`
            let urls = (try? await Self.retrieveEventImages(eventId: eventId)) ?? []
            await completion(urls)                       // closure is MainActor-isolated
        }
    }
    
    static func retrieveImagesForEventIds(_ eventIds: [String]) async throws -> [String: [String]] {
        try await withThrowingTaskGroup(of: (String, [String]).self) { group in
            for id in eventIds {
                group.addTask {
                    let urls = try await Self.retrieveEventImages(eventId: id)
                    return (id, urls)
                }
            }
            
            var out: [String: [String]] = [:]
            for try await (id, urls) in group { out[id] = urls }
            return out
        }
    }
    
    /// Fetch URLs for a single event (static to avoid capturing `self`)
    static func retrieveEventImages(eventId: String) async throws -> [String] {
        let folderRef = Storage.storage().reference(withPath: "event_images/\(eventId.lowercased())")
        let allPaths = try await folderRef.listAllPathsAsync()

        let itemPaths = allPaths.filter { $0.contains(eventId.lowercased()) }
        
        guard !itemPaths.isEmpty else { return [] }
        
        return try await withThrowingTaskGroup(of: String.self) { group in
            for path in itemPaths {
                group.addTask {
                    let ref = Storage.storage().reference(withPath: path)
                    let url = try await ref.downloadURLAsync()
                    return url.absoluteString
                }
            }
            var urls: [String] = []
            for try await s in group { urls.append(s) }
            return urls
        }
    }
    
}

private extension FirebaseEventImageManager {
    /// Returns item fullPaths (Strings) for a folder.
    static func listAllPaths(atPath folderPath: String) async throws -> [String] {
        let ref = Storage.storage().reference(withPath: folderPath)
        return try await withCheckedThrowingContinuation { cont in
            ref.listAll { result, error in
                if let error {
                    cont.resume(throwing: error)
                } else if let result {
                    // Extract only the Sendable bits we need (Strings)
                    let paths = result.items.map { $0.fullPath }
                    cont.resume(returning: paths)
                } else {
                    cont.resume(throwing: NSError(domain: "Storage", code: -1))
                }
            }
        }
    }
}

extension FirebaseEventImageManager {
    static func deleteImagesAsync(eventId: String) async throws {
        try await withCheckedThrowingContinuation { cont in
            deleteImages(eventId: eventId) { result in
                switch result {
                case .success:        cont.resume()
                case .failure(let e): cont.resume(throwing: e)
                }
            }
        }
    }
}

private extension StorageReference {
    func listAllPathsAsync() async throws -> [String] {
        try await withCheckedThrowingContinuation { cont in
            listAll { result, error in
                if let error {
                    cont.resume(throwing: error)
                } else if let result {
                    let paths = result.items.map { $0.fullPath }
                    cont.resume(returning: paths)
                } else {
                    cont.resume(throwing: NSError(domain: "Storage", code: -1))
                }
            }
        }
    }
    
    func downloadURLAsync() async throws -> URL {
        try await withCheckedThrowingContinuation { cont in
            downloadURL { url, error in
                if let error { cont.resume(throwing: error) }
                else if let url { cont.resume(returning: url) }
                else { cont.resume(throwing: NSError(domain: "Storage", code: -2)) }
            }
        }
    }
}
