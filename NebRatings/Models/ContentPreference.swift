//
//  ContentPreference.swift
//  NebRatings
//
//  The maturity level a user wants RECOMMENDED to them. This gates what
//  Discover, moods, seasonal collections, trending, personalized rows, and
//  Watch Together surface — it never limits search, direct navigation,
//  shared links, or other users' profiles/reviews/lists.
//
//  Enforcement is layered:
//    • Movie discover queries get a US certification cap (TMDB supports
//      certification.lte for movies only).
//    • Family-friendly queries also exclude mature-leaning genres, and TV
//      queries (no TMDB cert filter exists) lean on genre allow/exclude
//      lists instead.
//    • List-style endpoints (trending, recommendations) that can't be
//      filtered server-side get a client-side genre screen via `allows(_:)`.
//  Designed so more levels (custom caps, parental PIN, per-country
//  certifications) slot in without architectural change.
//

import Foundation

enum ContentPreference: String, Codable, CaseIterable, Identifiable {
    case familyFriendly = "family"
    case generalAudience = "general"
    case noRestrictions = "none"

    var id: String { rawValue }

    /// Lower = more restrictive. Groups adopt their minimum.
    var restrictionRank: Int {
        switch self {
        case .familyFriendly: return 0
        case .generalAudience: return 1
        case .noRestrictions: return 2
        }
    }

    static func mostRestrictive(_ preferences: [ContentPreference]) -> ContentPreference {
        preferences.min { $0.restrictionRank < $1.restrictionRank } ?? .generalAudience
    }

    // MARK: - Presentation

    var emoji: String {
        switch self {
        case .familyFriendly: return "👨‍👩‍👧‍👦"
        case .generalAudience: return "🎬"
        case .noRestrictions: return "🍿"
        }
    }

    var title: String {
        switch self {
        case .familyFriendly: return "Family Friendly"
        case .generalAudience: return "General Audience"
        case .noRestrictions: return "No Restrictions"
        }
    }

    var subtitle: String {
        switch self {
        case .familyFriendly: return "Recommended for families and younger audiences."
        case .generalAudience: return "Includes most movies and TV shows while filtering mature content."
        case .noRestrictions: return "Show all recommendations."
        }
    }

    // MARK: - TMDB query ingredients

    /// US movie certification ceiling for /discover/movie
    /// (certification.lte). nil = no cap.
    var movieCertificationCap: String? {
        switch self {
        case .familyFriendly: return "PG"
        case .generalAudience: return "PG-13"
        case .noRestrictions: return nil
        }
    }

    /// Genres excluded from recommendation QUERIES for this level.
    func excludedGenreIDs(for category: Show.Category) -> [Int] {
        guard self == .familyFriendly else { return [] }
        switch category {
        case .movie:
            return [27, 53, 80, 10752] // Horror, Thriller, Crime, War
        case .series:
            return [80, 10768, 9648]   // Crime, War & Politics, Mystery
        }
    }

    /// When a family-friendly query has no genres of its own, steer it
    /// toward the spec's priority genres instead of "everything under PG".
    func fallbackGenreIDs(for category: Show.Category) -> [Int] {
        guard self == .familyFriendly else { return [] }
        switch category {
        case .movie:
            return [10751, 16, 12, 35, 14]        // Family, Animation, Adventure, Comedy, Fantasy
        case .series:
            return [10751, 10762, 16, 35, 10759, 10765] // Family, Kids, Animation, Comedy, Action&Adv, Sci-Fi&Fantasy
        }
    }

    /// Genre names that disqualify a title client-side (for endpoints with
    /// no server-side filter, e.g. trending / recommendation lists).
    private var excludedGenreNames: Set<String> {
        switch self {
        case .familyFriendly: return ["Horror", "Thriller", "Crime", "War"]
        case .generalAudience: return []
        case .noRestrictions: return []
        }
    }

    /// Client-side screen. Titles with no genre data pass for general/none
    /// but are dropped for family-friendly (can't verify → don't recommend).
    func allows(_ show: Show) -> Bool {
        switch self {
        case .noRestrictions, .generalAudience:
            return true
        case .familyFriendly:
            guard !show.genres.isEmpty else { return false }
            return excludedGenreNames.isDisjoint(with: show.genres)
        }
    }
}
