//
//  FriendshipService.swift
//  Vibesy
//
//  Created by Alexander Cleoni on 1/24/25.
//

import Foundation

protocol FriendshipService {
    func sendFriendRequest(fromUserId: String, fromUserProfile: UserProfile, toUserId: String, message: String?, completion: @escaping (Error?) -> Void)
    func acceptFriendRequest(fromUserId: String, toUserId: String, completion: @escaping (Error?) -> Void)
    func deleteFriendRequest(fromUserId: String, toUserId: String, completion: @escaping (Error?) -> Void)
    func fetchPendingFriendRequests(userId: String, status: String, completion: @escaping ([FriendRequest]?, Error?) -> Void)
    func fetchFriendList(userId: String, completion: @escaping ([String]?, Error?) -> Void)
}
