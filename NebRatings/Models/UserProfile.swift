//
//  UserProfile.swift
//  NebRatings
//
//  Created by Cole Whaley on 11/29/25.
//

import Foundation

struct UserProfile: Identifiable, Hashable {
    let id: String
    let username: String
    let avatarEmoji: String?
    let avatarPhotoURL: String?

    init(id: String, username: String, avatarEmoji: String? = nil, avatarPhotoURL: String? = nil) {
        self.id = id
        self.username = username
        self.avatarEmoji = avatarEmoji
        self.avatarPhotoURL = avatarPhotoURL
    }

    static let sample = UserProfile(
        id: "sample-user-001",
        username: "Nebula Critic",
        avatarEmoji: "👽"
    )
}
