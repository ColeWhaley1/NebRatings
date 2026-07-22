//
//  SeasonalCollections.swift
//  NebRatings
//
//  Time-of-year curated collections for the Discover page: seasonal rows
//  (Christmas, Halloween Horror, Summer Blockbusters, …) that activate on
//  month/day windows. The built-in catalog below ships with the app; a
//  Firestore config document (appConfig/seasonalCollections) can override
//  it entirely, so collections can be re-curated any time WITHOUT an app
//  update. TMDB supplies the titles via genre + keyword discover queries.
//

import Foundation

struct SeasonalCollection: Identifiable, Hashable {
    let id: String
    let title: String
    let emoji: String
    let subtitle: String?

    /// Active window, year-agnostic, inclusive. Supports wrapping across
    /// New Year (e.g. Dec 27 → Jan 7).
    let startMonth: Int
    let startDay: Int
    let endMonth: Int
    let endDay: Int

    /// TMDB query ingredients. Genres are AND-ed with keywords; keywords are
    /// resolved to TMDB keyword IDs at runtime (OR semantics between them).
    /// Empty movie/tv genre arrays with `moviesOnly`/`tvOnly` control media.
    let movieGenreIDs: [Int]
    let tvGenreIDs: [Int]
    let keywords: [String]
    let includeMovies: Bool
    let includeTV: Bool
    let minVoteAverage: Double?
    let minVoteCount: Int?
    /// Sort order for the discover query (default popularity).
    let sortBy: String

    init(id: String,
         title: String,
         emoji: String,
         subtitle: String? = nil,
         startMonth: Int, startDay: Int,
         endMonth: Int, endDay: Int,
         movieGenreIDs: [Int] = [],
         tvGenreIDs: [Int] = [],
         keywords: [String] = [],
         includeMovies: Bool = true,
         includeTV: Bool = false,
         minVoteAverage: Double? = 6.0,
         minVoteCount: Int? = 100,
         sortBy: String = "popularity.desc") {
        self.id = id
        self.title = title
        self.emoji = emoji
        self.subtitle = subtitle
        self.startMonth = startMonth
        self.startDay = startDay
        self.endMonth = endMonth
        self.endDay = endDay
        self.movieGenreIDs = movieGenreIDs
        self.tvGenreIDs = tvGenreIDs
        self.keywords = keywords
        self.includeMovies = includeMovies
        self.includeTV = includeTV
        self.minVoteAverage = minVoteAverage
        self.minVoteCount = minVoteCount
        self.sortBy = sortBy
    }

    /// Whether the collection's window contains `date` (year ignored).
    func isActive(on date: Date, calendar: Calendar = .current) -> Bool {
        let month = calendar.component(.month, from: date)
        let day = calendar.component(.day, from: date)
        let now = month * 100 + day
        let start = startMonth * 100 + startDay
        let end = endMonth * 100 + endDay
        if start <= end {
            return now >= start && now <= end
        }
        // Window wraps the new year (e.g. 1227 → 0107).
        return now >= start || now <= end
    }
}

enum SeasonalCatalog {
    /// The built-in schedule. Firestore's appConfig/seasonalCollections
    /// document replaces this wholesale when present, so curation lives
    /// server-side and this list is the offline/first-launch fallback.
    static let builtIn: [SeasonalCollection] = [
        // ── Winter ────────────────────────────────────────────────────────
        SeasonalCollection(
            id: "christmas-movies", title: "Christmas Movies", emoji: "🎄",
            subtitle: "Tis the season",
            startMonth: 12, startDay: 1, endMonth: 12, endDay: 26,
            keywords: ["christmas"]
        ),
        SeasonalCollection(
            id: "holiday-tv-specials", title: "Holiday TV Specials", emoji: "🎁",
            startMonth: 12, startDay: 1, endMonth: 12, endDay: 26,
            keywords: ["christmas", "holiday"],
            includeMovies: false, includeTV: true, minVoteCount: 30
        ),
        SeasonalCollection(
            id: "new-years", title: "New Year's Favorites", emoji: "🎆",
            startMonth: 12, startDay: 27, endMonth: 1, endDay: 7,
            keywords: ["new year's eve", "new year"]
        ),
        SeasonalCollection(
            id: "cozy-winter", title: "Cozy Winter Movies", emoji: "❄️",
            startMonth: 1, startDay: 8, endMonth: 2, endDay: 28,
            movieGenreIDs: [35, 10751], keywords: ["winter"], minVoteCount: 50
        ),
        // ── Events: late winter / early spring ───────────────────────────
        SeasonalCollection(
            id: "valentines", title: "Valentine's Day", emoji: "💘",
            subtitle: "Love is in the air",
            startMonth: 2, startDay: 1, endMonth: 2, endDay: 14,
            movieGenreIDs: [10749], minVoteAverage: 6.5, minVoteCount: 300
        ),
        SeasonalCollection(
            id: "super-bowl", title: "Game Day Stories", emoji: "🏈",
            subtitle: "Sports docs for the big weekend",
            startMonth: 2, startDay: 1, endMonth: 2, endDay: 14,
            movieGenreIDs: [99], keywords: ["american football", "sports"],
            minVoteCount: 20
        ),
        SeasonalCollection(
            id: "oscars-season", title: "Oscars Season", emoji: "🏆",
            subtitle: "Critically acclaimed picks",
            startMonth: 2, startDay: 15, endMonth: 3, endDay: 15,
            minVoteAverage: 7.8, minVoteCount: 3000, sortBy: "vote_average.desc"
        ),
        SeasonalCollection(
            id: "womens-day", title: "Women Who Lead", emoji: "💪",
            subtitle: "For International Women's Day",
            startMonth: 3, startDay: 1, endMonth: 3, endDay: 15,
            keywords: ["strong female lead", "feminism"], minVoteCount: 50
        ),
        // ── Spring ───────────────────────────────────────────────────────
        SeasonalCollection(
            id: "spring-break", title: "Spring Break Movies", emoji: "🌴",
            startMonth: 3, startDay: 1, endMonth: 4, endDay: 15,
            movieGenreIDs: [35, 12], minVoteCount: 200
        ),
        SeasonalCollection(
            id: "family-adventures", title: "Family Adventures", emoji: "🧭",
            startMonth: 3, startDay: 15, endMonth: 5, endDay: 31,
            movieGenreIDs: [10751, 12], minVoteAverage: 6.5, minVoteCount: 200
        ),
        SeasonalCollection(
            id: "feel-good-spring", title: "Feel-Good Movies", emoji: "🌸",
            startMonth: 4, startDay: 1, endMonth: 5, endDay: 31,
            movieGenreIDs: [35], minVoteAverage: 7.0, minVoteCount: 300
        ),
        // ── Summer ───────────────────────────────────────────────────────
        SeasonalCollection(
            id: "pride-month", title: "Pride Picks", emoji: "🏳️‍🌈",
            subtitle: "Celebrate Pride Month",
            startMonth: 6, startDay: 1, endMonth: 6, endDay: 30,
            keywords: ["lgbt"], minVoteAverage: 6.8, minVoteCount: 50
        ),
        SeasonalCollection(
            id: "summer-blockbusters", title: "Summer Blockbusters", emoji: "🍿",
            startMonth: 6, startDay: 1, endMonth: 8, endDay: 31,
            movieGenreIDs: [28, 12], minVoteCount: 1500
        ),
        SeasonalCollection(
            id: "beach-movies", title: "Beach Movies", emoji: "🏖️",
            startMonth: 6, startDay: 1, endMonth: 7, endDay: 31,
            keywords: ["beach", "surfing"], minVoteCount: 50
        ),
        SeasonalCollection(
            id: "independence-day", title: "Independence Day Watchlist", emoji: "🇺🇸",
            startMonth: 6, startDay: 25, endMonth: 7, endDay: 5,
            keywords: ["4th of july", "independence day"], minVoteCount: 30
        ),
        SeasonalCollection(
            id: "summer-romance", title: "Summer Romance", emoji: "💞",
            startMonth: 7, startDay: 1, endMonth: 8, endDay: 31,
            movieGenreIDs: [10749], minVoteAverage: 6.5, minVoteCount: 200
        ),
        SeasonalCollection(
            id: "action-favorites", title: "Action Favorites", emoji: "💥",
            startMonth: 6, startDay: 1, endMonth: 8, endDay: 31,
            movieGenreIDs: [28], minVoteAverage: 7.0, minVoteCount: 1000
        ),
        // ── Back to school ───────────────────────────────────────────────
        SeasonalCollection(
            id: "back-to-school", title: "Back to School", emoji: "🎒",
            startMonth: 8, startDay: 15, endMonth: 9, endDay: 15,
            keywords: ["high school", "college"], minVoteCount: 100
        ),
        // ── Fall ─────────────────────────────────────────────────────────
        SeasonalCollection(
            id: "halloween-horror", title: "Halloween Horror", emoji: "🎃",
            subtitle: "Scares for spooky season",
            startMonth: 10, startDay: 1, endMonth: 10, endDay: 31,
            movieGenreIDs: [27], minVoteCount: 300
        ),
        SeasonalCollection(
            id: "psych-thrillers", title: "Psychological Thrillers", emoji: "🧠",
            startMonth: 10, startDay: 1, endMonth: 11, endDay: 15,
            movieGenreIDs: [53], keywords: ["psychological thriller"], minVoteCount: 100
        ),
        SeasonalCollection(
            id: "mystery-series", title: "Mystery Series", emoji: "🔍",
            startMonth: 9, startDay: 15, endMonth: 11, endDay: 30,
            tvGenreIDs: [9648], includeMovies: false, includeTV: true,
            minVoteAverage: 7.3, minVoteCount: 100
        ),
        SeasonalCollection(
            id: "cozy-autumn", title: "Cozy Autumn Shows", emoji: "🍂",
            startMonth: 9, startDay: 1, endMonth: 11, endDay: 30,
            tvGenreIDs: [35, 18], includeMovies: false, includeTV: true,
            minVoteAverage: 7.5, minVoteCount: 200
        ),
        SeasonalCollection(
            id: "thanksgiving", title: "Thanksgiving Watchlist", emoji: "🦃",
            startMonth: 11, startDay: 15, endMonth: 11, endDay: 30,
            keywords: ["thanksgiving"], minVoteCount: 20
        )
    ]

    /// Collections whose window contains today.
    static func active(from collections: [SeasonalCollection], on date: Date = Date()) -> [SeasonalCollection] {
        collections.filter { $0.isActive(on: date) }
    }
}
