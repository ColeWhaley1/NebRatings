//
//  YearInReview.swift
//  NebRatings
//
//  "NebRatings Wrapped" — the annual recap. The engine is pure: it takes
//  the user's reviews for the year, resolved Show details (for genres,
//  decades, TMDB ratings), list creation dates, and a pre-computed best
//  friend match, and derives every page's numbers. The store gathers the
//  inputs (see NebRatingsStore.buildYearInReview).
//
//  Deliberately deferred (needs TMDB credits endpoints): most-watched
//  actor / director / franchise.
//

import Foundation

struct YearInReviewStats {
    let year: Int

    // Overview
    let moviesWatched: Int
    let showsWatched: Int
    let reviewsWritten: Int
    let listsCreated: Int
    let estimatedHours: Int

    // Genres
    struct GenreShare: Identifiable, Hashable {
        let name: String
        let share: Double // 0…1
        var id: String { name }
    }
    let topGenres: [GenreShare]

    // Top rated
    let favoriteMovie: Review?
    let favoriteShow: Review?
    let hiddenGem: Review?
    let favoriteNewRelease: Review?
    let highestRatedSeason: Review?

    // Habits
    let mostActiveMonth: String?
    let mostActiveWeekday: String?
    let averageRating: Double?
    let longestStreakDays: Int
    let favoriteDecade: String?

    // Friends
    let mostCompatibleFriend: (profile: UserProfile, score: Int)?

    // Fun facts
    let mostControversial: (review: Review, delta: Double)?
    let biggestSurprise: (review: Review, delta: Double)?

    var isEmpty: Bool { reviewsWritten == 0 }
}

enum YearInReviewEngine {

    /// - Parameters:
    ///   - reviews: the user's reviews written during `year`.
    ///   - shows: resolved Show details keyed by TMDB id (best effort).
    ///   - listCreationDates: creation dates of lists the user owns.
    ///   - bestFriend: highest-compatibility friend, pre-computed.
    static func build(year: Int,
                      reviews: [Review],
                      shows: [Int: Show],
                      listCreationDates: [Date],
                      bestFriend: (profile: UserProfile, score: Int)?) -> YearInReviewStats {
        let calendar = Calendar.current

        let movieIDs = Set(reviews.filter { $0.showCategory == .movie }.map(\.showID))
        let seriesIDs = Set(reviews.filter { $0.showCategory == .series }.map(\.showID))

        // Crude but honest estimate: ~2h per movie, ~8h per rated series.
        let estimatedHours = movieIDs.count * 2 + seriesIDs.count * 8

        // ── Genres (weighted by review count per show) ────────────────────
        var genreCounts: [String: Int] = [:]
        for review in reviews {
            for genre in shows[review.showID]?.genres ?? [] {
                genreCounts[genre, default: 0] += 1
            }
        }
        let genreTotal = max(1, genreCounts.values.reduce(0, +))
        let topGenres = genreCounts
            .sorted { $0.value != $1.value ? $0.value > $1.value : $0.key < $1.key }
            .prefix(5)
            .map { YearInReviewStats.GenreShare(name: $0.key, share: Double($0.value) / Double(genreTotal)) }

        // ── Top rated ─────────────────────────────────────────────────────
        func top(_ filtered: [Review]) -> Review? {
            filtered.max { lhs, rhs in
                if lhs.nebRating != rhs.nebRating { return lhs.nebRating < rhs.nebRating }
                return lhs.timestamp < rhs.timestamp
            }
        }
        let favoriteMovie = top(reviews.filter { $0.showCategory == .movie })
        let favoriteShow = top(reviews.filter { $0.showCategory == .series })
        let hiddenGem = top(reviews.filter { review in
            guard review.nebRating >= 8, let show = shows[review.showID] else { return false }
            // Low TMDB popularity = flew under the radar.
            return show.popularity > 0 && show.popularity < 15
        })
        let favoriteNewRelease = top(reviews.filter { review in
            guard let show = shows[review.showID] else { return false }
            return show.year >= year
        })
        let highestRatedSeason = top(reviews.filter { $0.season != nil })

        // ── Habits ────────────────────────────────────────────────────────
        var byMonth: [Int: Int] = [:]
        var byWeekday: [Int: Int] = [:]
        var reviewDays = Set<DateComponents>()
        for review in reviews {
            byMonth[calendar.component(.month, from: review.timestamp), default: 0] += 1
            byWeekday[calendar.component(.weekday, from: review.timestamp), default: 0] += 1
            reviewDays.insert(calendar.dateComponents([.year, .month, .day], from: review.timestamp))
        }
        let monthName: String? = byMonth.max { $0.value < $1.value }.map {
            calendar.monthSymbols[$0.key - 1]
        }
        let weekdayName: String? = byWeekday.max { $0.value < $1.value }.map {
            calendar.weekdaySymbols[$0.key - 1]
        }

        let averageRating = reviews.isEmpty
            ? nil
            : reviews.reduce(0.0) { $0 + $1.nebRating } / Double(reviews.count)

        // Longest run of consecutive days with at least one review.
        let sortedDays = reviewDays.compactMap(calendar.date(from:)).sorted()
        var longestStreak = sortedDays.isEmpty ? 0 : 1
        var currentStreak = longestStreak
        for index in 1..<max(1, sortedDays.count) where index < sortedDays.count {
            let gap = calendar.dateComponents([.day], from: sortedDays[index - 1], to: sortedDays[index]).day ?? 0
            currentStreak = gap == 1 ? currentStreak + 1 : 1
            longestStreak = max(longestStreak, currentStreak)
        }

        // Favorite decade from the release years of everything reviewed.
        var byDecade: [Int: Int] = [:]
        for review in reviews {
            if let show = shows[review.showID], show.year > 1900 {
                byDecade[(show.year / 10) * 10, default: 0] += 1
            }
        }
        let favoriteDecade = byDecade.max { lhs, rhs in
            lhs.value != rhs.value ? lhs.value < rhs.value : lhs.key > rhs.key
        }.map { "\($0.key)s" }

        // ── Fun facts: vs the wider world ─────────────────────────────────
        // Delta between the user's neb rating and TMDB's community rating.
        let withCommunity: [(review: Review, delta: Double)] = reviews.compactMap { review in
            guard let tmdb = shows[review.showID]?.rating, tmdb > 0 else { return nil }
            return (review, review.nebRating - tmdb)
        }
        let mostControversial = withCommunity.max { abs($0.delta) < abs($1.delta) }
        let biggestSurprise = withCommunity
            .filter { $0.delta >= 1.5 && $0.review.nebRating >= 8 }
            .max { $0.delta < $1.delta }

        // ── Lists ─────────────────────────────────────────────────────────
        let listsCreated = listCreationDates.filter {
            calendar.component(.year, from: $0) == year
        }.count

        return YearInReviewStats(
            year: year,
            moviesWatched: movieIDs.count,
            showsWatched: seriesIDs.count,
            reviewsWritten: reviews.count,
            listsCreated: listsCreated,
            estimatedHours: estimatedHours,
            topGenres: Array(topGenres),
            favoriteMovie: favoriteMovie,
            favoriteShow: favoriteShow,
            hiddenGem: hiddenGem,
            favoriteNewRelease: favoriteNewRelease,
            highestRatedSeason: highestRatedSeason,
            mostActiveMonth: monthName,
            mostActiveWeekday: weekdayName,
            averageRating: averageRating,
            longestStreakDays: longestStreak,
            favoriteDecade: favoriteDecade,
            mostCompatibleFriend: bestFriend,
            mostControversial: mostControversial,
            biggestSurprise: biggestSurprise
        )
    }
}
