//
//  FirebaseProfileImageManager.swift
//  Vibesy
//
//  Created by Alexander Cleoni on 12/15/24.
//
import SwiftUI
import FirebaseStorage

class FirebaseProfileImageManager {
    let storage = Storage.storage() // Direct singleton access
    
    func upload(uid: String, image: UIImage, completion: @escaping (Result<String, Error>) -> Void) {
        let storageRef = storage.reference().child("users/\(uid)/images/\(uid)-image.jpg")
        
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            completion(.failure(NSError(domain: "ImageError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to compress image"])))
            return
        }
        
        storageRef.putData(imageData) { _, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            storageRef.downloadURL { url, error in
                if let error = error {
                    completion(.failure(error))
                } else if let url = url {
                    completion(.success(url.absoluteString))
                }
            }
        }
        
    }
}
