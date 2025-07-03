//
//  FirebaseFriendshipService.swift
//  Vibesy
//
//  Created by Alexander Cleoni on 1/24/25.
//
import Foundation

class FirebaseFriendshipService: FriendshipService {
    private let friendshipManager = FirebaseFriendshipManager()
    func sendFriendRequest(fromUserId: String, fromUserProfile: UserProfile, toUserId: String, message: String?, completion: @escaping (Error?) -> Void) {
        friendshipManager.sendFriendRequest(fromUserId: fromUserId, fromUserProfile: fromUserProfile, toUserId: toUserId, message: message) { error in
            if let error = error {
                print("Error sending friend request: \(error)")
                completion(error)
            } else {
                self.sendPushNotification(fromUserId: fromUserId, toUserId: toUserId) { notificationError in
                    completion(notificationError)
                }
            }
        }
    }
    
    func deleteFriendRequest(fromUserId: String, toUserId: String, completion: @escaping (Error?) -> Void) {
        friendshipManager.deleteFriendRequest(fromUserId: fromUserId, toUserId: toUserId) { error in
            if let error = error {
                print("Error sending friend request: \(error)")
                completion(error)
            } else {
                completion(nil)
            }
        }
    }
    
    func acceptFriendRequest(fromUserId: String, toUserId: String, completion: @escaping (Error?) -> Void) {
        friendshipManager.acceptFriendRequest(fromUserId: fromUserId, toUserId: toUserId) { error in
            if let error = error {
                print("Error sending friend request: \(error)")
                completion(error)
            } else {
                completion(nil)
            }
        }
    }
    
    func fetchPendingFriendRequests(userId: String, status: String, completion: @escaping ([FriendRequest]?, Error?) -> Void) {
        friendshipManager.fetchPendingFriendRequests(userId: userId, status: status) { (requests, error) in
            if let error = error {
                print("Error fetching friend requests: \(error.localizedDescription)")
                completion(nil, error)
            } else if let requests = requests {
                completion(requests, nil)
            }
        }
    }
    
    func fetchFriendList(userId: String, completion: @escaping ([String]?, Error?) -> Void) {
        friendshipManager.fetchFriendList(userId: userId) { (requests, error) in
            if let error = error {
                print("Error fetching friend requests: \(error.localizedDescription)")
                completion(nil, error)
            } else if let requests = requests {
                completion(requests, nil)
            }
        }
    }
    
    // Send a push notification to the recipient
    private func sendPushNotification(fromUserId: String, toUserId: String, completion: @escaping (Error?) -> Void) {
        // Call your backend API to send the notification
        let url = URL(string: "https://one-time-password-service.onrender.com/notifications/send")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Prepare the notification payload
        let payload: [String: Any] = [
            "title": "New Friend Request",
            "body":  "You have a new friend request",
            "toUserId": "\(toUserId)",
            "fromUserId": "\(fromUserId)"
        ]
        
        // Serialize the payload to JSON
        request.httpBody = try? JSONSerialization.data(withJSONObject: payload, options: [])
        
        // Send the request
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("Error sending notification: \(error)")
                completion(error)
            } else {
                print("Notification sent successfully!")
                completion(nil)
            }
        }
        task.resume()
    }
}


