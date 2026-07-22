//
//  GroupRecommendations.swift
//  NebRatings
//
//  "Watch Together" scoring: given a group's reviews, tastes, and
//  watchlists plus a pool of candidate titles (gathered by the store from
//  TMDB seeds/genres/gems/watchlists), rank what the whole group is most
//  likely to enjoy. Pure logic — no I/O — mirroring CompatibilityEngine.
//
//  Hard exclusions:
//    • titles every member has already watched (rated)
//    • titles any member rated poorly (< 4 nebs)
//  Score favors "nobody will hate it" (min member score weighs more than
//  the mean), then adds a small TMDB quality prior.
//

import Foundation

/// One participant in a Watch Together session.
struct GroupMember: Identifiable {
    let profile: UserProfile
    let reviews: [Review]
    /// Show ids sitting on this member's (visible) lists.
    let watchlistShowIDs: Set<Int>

    var id: String { profile.id }

    /// showID → average rating (season reviews collapsed).
    var ratingsByShow: [Int: Double] {
        var sums: [Int: (sum: Double, count: Int)] = [:]
        for review in reviews {
            var entry = sums[review.showID] ?? (0, 0)
            entry.sum += review.nebRating
            entry.count += 1
            sums[review.showID] = entry
        }
        return sums.mapValues { $0.sum / Double($0.count) }
    }

    /// Genre → share of this member's reviews (0…1).
    var genreShares: [String: Double] {
        guard let counts = profile.genreCounts, !counts.isEmpty else { return [:] }
        let total = Double(counts.values.reduce(0, +))
        guard total > 0 else { return [:] }
        return counts.mapValues { Double($0) / total }
    }
}

/// Why a candidate entered the pool — drives the "Recommended because" copy.
enum CandidateSource: Hashable {
    case seededBy(title: String)          // TMDB recs from a title the group loved
    case sharedGenre(genre: String)
    case hiddenGem
    case watchlist(memberName: String)
}

struct GroupRecommendation: Identifiable {
    let show: Show
    /// 55–98; presented as "96% Match".
    let confidence: Int
    /// Human-readable "Recommended because:" bullets.
    let reasons: [String]
    var id: Int { show.id }
}

enum GroupRecommendationEngine {

    static func recommend(members: [GroupMember],
                          candidates: [Show: Set<CandidateSource>],
                          limit: Int = 12) -> [GroupRecommendation] {
        guard !members.isEmpty else { return [] }
        let memberRatings = members.map(\.ratingsByShow)

        var scored: [(rec: GroupRecommendation, score: Double)] = []

        for (show, sources) in candidates {
            // Exclusion: everyone has already watched it.
            let watchedCount = memberRatings.filter { $0[show.id] != nil }.count
            if watchedCount == members.count { continue }
            // Exclusion: someone hated it.
            if memberRatings.contains(where: { ($0[show.id] ?? 10) < 4 }) { continue }

            var perMember: [Double] = []
            for (index, member) in members.enumerated() {
                perMember.append(predictedEnjoyment(
                    of: show,
                    for: member,
                    rating: memberRatings[index][show.id]
                ))
            }

            let minScore = perMember.min() ?? 0.5
            let meanScore = perMember.reduce(0, +) / Double(perMember.count)
            // Nobody-hates-it beats somebody-loves-it.
            var groupScore = 0.6 * minScore + 0.4 * meanScore

            // Small TMDB quality prior (6.0 neutral, 8.0 → +0.05).
            if let rating = show.rating, rating > 0 {
                groupScore += max(-0.05, min(0.05, (rating - 6.0) / 40.0))
            }
            // Watchlist intent is a strong group signal.
            if sources.contains(where: { if case .watchlist = $0 { return true }; return false }) {
                groupScore += 0.04
            }

            let confidence = min(98, max(55, Int((groupScore * 100).rounded())))
            let reasons = reasons(for: show, sources: sources, members: members, ratings: memberRatings)

            scored.append((GroupRecommendation(show: show, confidence: confidence, reasons: reasons), groupScore))
        }

        return scored
            .sorted { $0.score > $1.score }
            .prefix(limit)
            .map(\.rec)
    }

    // MARK: - Per-member prediction

    /// 0.3–0.98: how much this member is likely to enjoy the title.
    /// Anchored to the member's own rating behavior: someone who averages
    /// 8s predicts higher than someone who averages 6s, so the confidence
    /// numbers track how the group actually rates things.
    private static func predictedEnjoyment(of show: Show,
                                           for member: GroupMember,
                                           rating: Double?) -> Double {
        // They've seen it: their own verdict IS the prediction.
        if let rating {
            return min(0.98, max(0.3, rating / 10.0))
        }

        // Personalized baseline: their average rating, pulled toward the
        // middle (unseen ≠ favorite), clamped to a sane band.
        let ratings = member.ratingsByShow.values
        let baseline: Double
        if ratings.isEmpty {
            baseline = 0.55
        } else {
            let average = ratings.reduce(0, +) / Double(ratings.count)
            baseline = min(0.7, max(0.45, (average / 10.0) * 0.85))
        }
        var score = baseline

        // Genre affinity: how much of their review history lives in this
        // title's genres (top two genres, diminishing returns).
        let shares = member.genreShares
        if !shares.isEmpty && !show.genres.isEmpty {
            let topShares = show.genres.map { shares[$0] ?? 0 }.sorted(by: >).prefix(2)
            let affinity = topShares.reduce(0, +)
            score += min(0.2, affinity * 0.8)
        }

        // Hand-picked favorite genres are an explicit signal.
        if let favorites = member.profile.favoriteGenres,
           show.genres.contains(where: favorites.contains) {
            score += 0.08
        }

        // Already on their watchlist — they literally asked for it.
        if member.watchlistShowIDs.contains(show.id) {
            score += 0.12
        }

        return min(0.98, max(0.3, score))
    }

    // MARK: - Explanations

    private static func reasons(for show: Show,
                                sources: Set<CandidateSource>,
                                members: [GroupMember],
                                ratings: [[Int: Double]]) -> [String] {
        var reasons: [String] = []

        // Strongest signal first: a member already rated it highly (never
        // everyone — those are excluded upstream).
        let watchers = zip(members, ratings).compactMap { member, memberRatings -> (GroupMember, Double)? in
            guard let rating = memberRatings[show.id] else { return nil }
            return (member, rating)
        }
        if watchers.count == 1, let watcher = watchers.first, watcher.1 >= 7 {
            // "rated", not "watched/seen" — someone may have watched a title
            // without rating it, and ratings are all the engine can know.
            reasons.append("\(watcher.0.profile.username) rated it \(String(format: "%.1f", watcher.1)) — the rest of you haven't rated it")
        }

        // Genre love, named to the members it actually applies to (12%+ of
        // their review history, or a hand-picked favorite genre).
        for genre in show.genres.prefix(2) {
            let lovers = members.filter { member in
                (member.genreShares[genre] ?? 0) >= 0.12
                    || (member.profile.favoriteGenres?.contains(genre) ?? false)
            }
            if lovers.count == members.count && members.count > 1 {
                reasons.append("Everyone in the group loves \(genre)")
                break
            } else if lovers.count >= 2 {
                let names = lovers.prefix(2).map(\.profile.username).joined(separator: " and ")
                reasons.append("\(names) both love \(genre)")
                break
            } else if members.count == 1, lovers.count == 1 {
                reasons.append("\(genre) is one of your favorite genres")
                break
            }
        }

        // Watchlist provenance — attributed to the list's OWNER.
        for source in sources {
            if case .watchlist(let name) = source {
                reasons.append("It's on \(name)'s watchlist")
                break
            }
        }

        // Seed provenance: recs that grew out of a title the group rated highly.
        for source in sources {
            if case .seededBy(let seedTitle) = source {
                reasons.append("Similar to \(seedTitle), which you rated highly")
                break
            }
        }

        // Hidden gem flavor.
        if sources.contains(.hiddenGem) {
            reasons.append("A hidden gem that fits your group's taste")
        }

        // Community quality, when it's genuinely strong.
        if reasons.count < 2, let tmdb = show.rating, tmdb >= 7.5 {
            reasons.append("Rated \(String(format: "%.1f", tmdb)) by the wider community")
        }

        if watchers.isEmpty {
            reasons.append("None of you have rated it yet")
        }

        if reasons.isEmpty {
            reasons.append("Popular with people whose taste matches yours")
        }
        return Array(reasons.prefix(3))
    }
}
