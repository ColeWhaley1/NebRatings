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

    // Persisted critic-harshness aggregate. Stored as a running sum/count so the
    // average (sum / count) can be maintained incrementally on each review write,
    // instead of recomputed from TMDB on every profile view.
    // nil count = aggregate has never been computed for this profile (needs backfill).
    let criticDeltaSum: Double?
    let criticDeltaCount: Int?

    init(id: String,
         username: String,
         avatarEmoji: String? = nil,
         criticDeltaSum: Double? = nil,
         criticDeltaCount: Int? = nil) {
        self.id = id
        self.username = username
        self.avatarEmoji = avatarEmoji
        self.criticDeltaSum = criticDeltaSum
        self.criticDeltaCount = criticDeltaCount
    }

    /// Average (nebRating − TMDB) across comparable reviews; nil if none.
    var criticDelta: Double? {
        guard let count = criticDeltaCount, count > 0, let sum = criticDeltaSum else { return nil }
        return sum / Double(count)
    }

    var criticSampleSize: Int { criticDeltaCount ?? 0 }

    /// True when the aggregate has never been computed (e.g. profiles that predate the feature).
    var needsCriticBackfill: Bool { criticDeltaCount == nil }

    static let sample = UserProfile(
        id: "sample-user-001",
        username: "Nebula Critic",
        avatarEmoji: "👽"
    )
}
