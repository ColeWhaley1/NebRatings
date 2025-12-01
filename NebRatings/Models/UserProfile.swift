//
//  UserProfile.swift
//  NebRatings
//
//  Created by Cole Whaley on 11/29/25.
//

import Foundation

struct UserProfile: Identifiable, Hashable {
    let id: String
    let displayName: String
    let bio: String

    static let sample = UserProfile(
        id: "sample-user-001",
        displayName: "Nebula Critic",
        bio: "Dropping nebs since 2025."
    )
}



