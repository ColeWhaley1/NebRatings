//
//  UserProfile.swift
//  NebRatings
//
//  Created by Cole Whaley on 11/29/25.
//

import Foundation

/// A user's hand-picked favorite movie or TV show, denormalized onto the
/// profile document (id + title + poster) so profiles render without a TMDB
/// round-trip. Tapping through fetches full details by `id`.
struct FavoriteTitle: Hashable, Codable {
    let id: Int // TMDB ID
    let title: String
    let posterURL: String?
    let category: Show.Category
}

struct UserProfile: Identifiable, Hashable {
    let id: String
    let username: String
    let avatarEmoji: String?

    /// Short self-description shown under the username. nil/empty = hidden.
    let bio: String?
    /// Hand-picked favorite genres (max 5), distinct from the review-derived
    /// `genreCounts` tally. Used for display + Discover personalization.
    let favoriteGenres: [String]?
    let favoriteMovie: FavoriteTitle?
    let favoriteShow: FavoriteTitle?
    /// Set once at profile creation. nil on profiles that predate the field.
    let joinDate: Date?

    // Persisted critic-harshness aggregate. Stored as a running sum/count so the
    // average (sum / count) can be maintained incrementally on each review write,
    // instead of recomputed from TMDB on every profile view.
    // nil count = aggregate has never been computed for this profile (needs backfill).
    let criticDeltaSum: Double?
    let criticDeltaCount: Int?

    // Persisted genre tally: genre name → how many of the user's reviews are for a
    // show in that genre. Maintained incrementally on each review write (same pattern
    // as the critic aggregate) so `topGenre` is an O(1) read with no TMDB lookups on
    // profile view. nil = never computed for this profile (needs backfill). An empty
    // (non-nil) map means "computed, but no qualifying reviews" — won't re-backfill.
    let genreCounts: [String: Int]?

    init(id: String,
         username: String,
         avatarEmoji: String? = nil,
         criticDeltaSum: Double? = nil,
         criticDeltaCount: Int? = nil,
         genreCounts: [String: Int]? = nil,
         bio: String? = nil,
         favoriteGenres: [String]? = nil,
         favoriteMovie: FavoriteTitle? = nil,
         favoriteShow: FavoriteTitle? = nil,
         joinDate: Date? = nil) {
        self.id = id
        self.username = username
        self.avatarEmoji = avatarEmoji
        self.criticDeltaSum = criticDeltaSum
        self.criticDeltaCount = criticDeltaCount
        self.genreCounts = genreCounts
        self.bio = bio
        self.favoriteGenres = favoriteGenres
        self.favoriteMovie = favoriteMovie
        self.favoriteShow = favoriteShow
        self.joinDate = joinDate
    }

    /// Average (nebRating − TMDB) across comparable reviews; nil if none.
    var criticDelta: Double? {
        guard let count = criticDeltaCount, count > 0, let sum = criticDeltaSum else { return nil }
        return sum / Double(count)
    }

    var criticSampleSize: Int { criticDeltaCount ?? 0 }

    /// True when the aggregate has never been computed (e.g. profiles that predate the feature).
    var needsCriticBackfill: Bool { criticDeltaCount == nil }

    /// The user's most-reviewed genre, or nil if there's no genre data yet.
    /// Ties break alphabetically (first name wins) so the result is deterministic.
    var topGenre: String? {
        guard let genreCounts else { return nil }
        let positive = genreCounts.filter { $0.value > 0 }
        guard let top = positive.max(by: { a, b in
            if a.value != b.value { return a.value < b.value }
            return a.key > b.key // equal counts → alphabetically-first key wins
        }) else { return nil }
        return top.key
    }

    /// True when the genre tally has never been computed (profiles predating the feature).
    var needsGenreBackfill: Bool { genreCounts == nil }

    static let sample = UserProfile(
        id: "sample-user-001",
        username: "Nebula Critic",
        avatarEmoji: "👽"
    )
}
