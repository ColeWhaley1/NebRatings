//
//  Compatibility.swift
//  NebRatings
//
//  Taste-compatibility scoring between two users. Pure functions over both
//  users' reviews + profiles — no I/O — so the same engine powers the
//  profile "Compare Tastes" screen, Watch Together explanations, and the
//  Year in Review friends page.
//
//  Score recipe (weights renormalize when a component lacks data):
//    • Rating similarity on shared titles ........ 45%
//    • Review-derived genre overlap (cosine) ..... 30%
//    • Hand-picked favorite genres (Jaccard) ..... 15%
//    • Shared high ratings + favorite titles ..... 10%
//

import Foundation

struct CompatibilityReport {
    /// 0–100. Clamped to 5…99 — nobody is a perfect 100 or an absolute 0.
    let score: Int
    /// Shared rated titles the comparison is based on.
    let sharedTitleCount: Int

    /// Genres both users demonstrably love.
    let bothLove: [String]
    /// Genres where one user is deep in and the other barely touches.
    let disagreeOn: [String]

    struct SharedFavorite: Identifiable, Hashable {
        let showID: Int
        let title: String
        let myRating: Double
        let theirRating: Double
        var id: Int { showID }
    }
    /// Titles both users rated highly (8+), best first.
    let sharedFavorites: [SharedFavorite]

    struct RatingDifference: Identifiable, Hashable {
        let showID: Int
        let title: String
        let myRating: Double
        let theirRating: Double
        var delta: Double { theirRating - myRating }
        var id: Int { showID }
    }
    /// Largest disagreements on shared titles (|Δ| ≥ 2 nebs), biggest first.
    let biggestDifferences: [RatingDifference]

    /// True when there wasn't enough overlap for a meaningful number —
    /// the UI should soften its claims.
    let isLowConfidence: Bool
}

enum CompatibilityEngine {

    static func report(myReviews: [Review],
                       theirReviews: [Review],
                       myProfile: UserProfile?,
                       theirProfile: UserProfile?) -> CompatibilityReport {
        // One rating per show per user (season reviews collapse by average).
        let mine = ratingsByShow(myReviews)
        let theirs = ratingsByShow(theirReviews)
        let sharedIDs = Set(mine.keys).intersection(theirs.keys)

        // ── Component 1: rating similarity on shared titles ──────────────
        var ratingSimilarity: Double?
        if !sharedIDs.isEmpty {
            let meanAbsDiff = sharedIDs
                .map { abs(mine[$0]!.rating - theirs[$0]!.rating) }
                .reduce(0, +) / Double(sharedIDs.count)
            // 0 diff → 1.0; 5+ nebs average gap → 0.
            ratingSimilarity = max(0, 1 - meanAbsDiff / 5.0)
        }

        // ── Component 2: review-derived genre overlap ─────────────────────
        let genreSimilarity = cosineSimilarity(
            normalized(myProfile?.genreCounts),
            normalized(theirProfile?.genreCounts)
        )

        // ── Component 3: hand-picked favorite genres ─────────────────────
        var favoriteGenreSimilarity: Double?
        if let a = myProfile?.favoriteGenres, let b = theirProfile?.favoriteGenres,
           !a.isEmpty, !b.isEmpty {
            let setA = Set(a), setB = Set(b)
            favoriteGenreSimilarity = Double(setA.intersection(setB).count) / Double(setA.union(setB).count)
        }

        // ── Component 4: shared favorites ────────────────────────────────
        let sharedFavorites = sharedIDs
            .filter { mine[$0]!.rating >= 8 && theirs[$0]!.rating >= 8 }
            .map {
                CompatibilityReport.SharedFavorite(
                    showID: $0,
                    title: mine[$0]!.title,
                    myRating: mine[$0]!.rating,
                    theirRating: theirs[$0]!.rating
                )
            }
            .sorted { ($0.myRating + $0.theirRating) > ($1.myRating + $1.theirRating) }
        var favoritesScore: Double? = nil
        if !sharedIDs.isEmpty {
            var boost = min(1.0, Double(sharedFavorites.count) / 5.0)
            if let a = myProfile?.favoriteMovie?.id, a == theirProfile?.favoriteMovie?.id { boost = min(1.0, boost + 0.3) }
            if let a = myProfile?.favoriteShow?.id, a == theirProfile?.favoriteShow?.id { boost = min(1.0, boost + 0.3) }
            favoritesScore = boost
        }

        // ── Blend with renormalized weights ──────────────────────────────
        var weighted: [(score: Double, weight: Double)] = []
        if let ratingSimilarity { weighted.append((ratingSimilarity, 0.45)) }
        if let genreSimilarity { weighted.append((genreSimilarity, 0.30)) }
        if let favoriteGenreSimilarity { weighted.append((favoriteGenreSimilarity, 0.15)) }
        if let favoritesScore { weighted.append((favoritesScore, 0.10)) }

        let totalWeight = weighted.reduce(0) { $0 + $1.weight }
        let blended: Double
        if totalWeight > 0 {
            blended = weighted.reduce(0) { $0 + $1.score * $1.weight } / totalWeight
        } else {
            blended = 0.5 // nothing to compare — neutral
        }
        let score = min(99, max(5, Int((blended * 100).rounded())))

        // ── Insights ─────────────────────────────────────────────────────
        let (bothLove, disagreeOn) = genreInsights(
            mine: normalized(myProfile?.genreCounts),
            theirs: normalized(theirProfile?.genreCounts),
            myFavorites: myProfile?.favoriteGenres ?? [],
            theirFavorites: theirProfile?.favoriteGenres ?? []
        )

        let differences = sharedIDs
            .map {
                CompatibilityReport.RatingDifference(
                    showID: $0,
                    title: mine[$0]!.title,
                    myRating: mine[$0]!.rating,
                    theirRating: theirs[$0]!.rating
                )
            }
            .filter { abs($0.delta) >= 2 }
            .sorted { abs($0.delta) > abs($1.delta) }

        return CompatibilityReport(
            score: score,
            sharedTitleCount: sharedIDs.count,
            bothLove: bothLove,
            disagreeOn: disagreeOn,
            sharedFavorites: Array(sharedFavorites.prefix(5)),
            biggestDifferences: Array(differences.prefix(5)),
            isLowConfidence: sharedIDs.count < 3 && totalWeight < 0.5
        )
    }

    // MARK: - Ingredients

    /// showID → (average rating, title) for one user.
    private static func ratingsByShow(_ reviews: [Review]) -> [Int: (rating: Double, title: String)] {
        var sums: [Int: (sum: Double, count: Int, title: String)] = [:]
        for review in reviews {
            var entry = sums[review.showID] ?? (0, 0, review.showTitle)
            entry.sum += review.nebRating
            entry.count += 1
            sums[review.showID] = entry
        }
        return sums.mapValues { ($0.sum / Double($0.count), $0.title) }
    }

    /// Genre tally → share-of-total map (sums to 1). nil/empty → nil.
    private static func normalized(_ counts: [String: Int]?) -> [String: Double]? {
        guard let counts, !counts.isEmpty else { return nil }
        let total = Double(counts.values.reduce(0, +))
        guard total > 0 else { return nil }
        return counts.mapValues { Double($0) / total }
    }

    private static func cosineSimilarity(_ a: [String: Double]?, _ b: [String: Double]?) -> Double? {
        guard let a, let b else { return nil }
        let keys = Set(a.keys).union(b.keys)
        var dot = 0.0, magA = 0.0, magB = 0.0
        for key in keys {
            let va = a[key] ?? 0
            let vb = b[key] ?? 0
            dot += va * vb
            magA += va * va
            magB += vb * vb
        }
        guard magA > 0, magB > 0 else { return nil }
        return dot / (magA.squareRoot() * magB.squareRoot())
    }

    /// "You both love" = genre prominent for both (or in both favorites).
    /// "You disagree on" = prominent for exactly one of you.
    private static func genreInsights(mine: [String: Double]?,
                                      theirs: [String: Double]?,
                                      myFavorites: [String],
                                      theirFavorites: [String]) -> (bothLove: [String], disagreeOn: [String]) {
        var bothLove = Array(Set(myFavorites).intersection(theirFavorites))

        if let mine, let theirs {
            let threshold = 0.12 // "prominent" = ≥12% of your reviews
            for genre in Set(mine.keys).union(theirs.keys) {
                let a = mine[genre] ?? 0
                let b = theirs[genre] ?? 0
                if a >= threshold && b >= threshold && !bothLove.contains(genre) {
                    bothLove.append(genre)
                }
            }
        }

        var disagree: [String] = []
        if let mine, let theirs {
            let high = 0.15, low = 0.03
            for genre in Set(mine.keys).union(theirs.keys) {
                let a = mine[genre] ?? 0
                let b = theirs[genre] ?? 0
                if (a >= high && b <= low) || (b >= high && a <= low) {
                    disagree.append(genre)
                }
            }
        }
        // Favorites one-sided (picked by one, absent for the other entirely)
        for genre in Set(myFavorites).symmetricDifference(theirFavorites)
        where !bothLove.contains(genre) && !disagree.contains(genre) {
            let otherCounts = myFavorites.contains(genre) ? theirs : mine
            if let share = otherCounts?[genre], share <= 0.03 {
                disagree.append(genre)
            } else if otherCounts == nil {
                // No review data for the other user — favorites disagreement
                // is the only signal we have.
                disagree.append(genre)
            }
        }

        return (Array(bothLove.prefix(5)), Array(disagree.prefix(4)))
    }
}
