//
//  Moods.swift
//  NebRatings
//
//  Mood-based discovery: each mood maps to TMDB Discover filters (genres,
//  rating/vote thresholds, runtime, recency, sort). A mood can target
//  movies, TV, or both — nil filter = that medium isn't offered.
//

import Foundation

/// Parameters for a TMDB /discover call. One filter targets one endpoint
/// (movie or tv); moods spanning both carry two filters.
struct DiscoverFilter: Hashable {
    /// How multiple `genreIDs` combine: `.all` = must have every genre
    /// (TMDB comma), `.any` = at least one (TMDB pipe).
    enum GenreMatch: Hashable {
        case all
        case any
    }

    var category: Show.Category
    var genreIDs: [Int] = []
    var genreMatch: GenreMatch = .all
    /// TMDB keyword IDs, OR-ed (pipe-joined). Resolved from names via
    /// /search/keyword — see TMDBService.fetchKeywordIDs.
    var keywordIDs: [Int] = []
    /// US certification ceiling for movie queries (certification.lte).
    /// Set by the store from the user's ContentPreference; nil = no cap.
    var movieCertificationCap: String? = nil
    /// Genres excluded via without_genres (content-preference driven).
    var excludedGenreIDs: [Int] = []
    var minVoteAverage: Double? = nil
    var minVoteCount: Int? = nil
    var maxVoteCount: Int? = nil
    /// Runtime bounds in minutes (movies; TMDB supports with_runtime for TV too).
    var minRuntime: Int? = nil
    var maxRuntime: Int? = nil
    var releasedAfter: Date? = nil
    var releasedBefore: Date? = nil
    var sortBy: String = "popularity.desc"
}

struct Mood: Identifiable, Hashable {
    let id: String
    let name: String
    let emoji: String
    let movieFilter: DiscoverFilter?
    let tvFilter: DiscoverFilter?
}

enum MoodCatalog {
    // TMDB genre IDs (movie): 28 Action, 12 Adventure, 16 Animation,
    // 35 Comedy, 80 Crime, 18 Drama, 10751 Family, 14 Fantasy, 27 Horror,
    // 9648 Mystery, 10749 Romance, 878 Sci-Fi, 53 Thriller.
    // TV: 10759 Action&Adventure, 10765 Sci-Fi&Fantasy, 35 Comedy, 80 Crime,
    // 18 Drama, 9648 Mystery, 10751 Family.

    static let all: [Mood] = [
        Mood(id: "feel-good", name: "Feel Good", emoji: "😊",
             movieFilter: DiscoverFilter(category: .movie, genreIDs: [35], minVoteAverage: 6.5, minVoteCount: 300),
             tvFilter: DiscoverFilter(category: .series, genreIDs: [35], minVoteAverage: 7.0, minVoteCount: 150)),
        Mood(id: "mind-bending", name: "Mind-Bending", emoji: "🌀",
             movieFilter: DiscoverFilter(category: .movie, genreIDs: [878, 53], minVoteAverage: 7.0, minVoteCount: 500),
             tvFilter: DiscoverFilter(category: .series, genreIDs: [10765, 9648], minVoteAverage: 7.5, minVoteCount: 200)),
        Mood(id: "cozy-night", name: "Cozy Night", emoji: "🛋️",
             movieFilter: DiscoverFilter(category: .movie, genreIDs: [35, 10751], minVoteAverage: 6.5, minVoteCount: 200, maxRuntime: 110),
             tvFilter: DiscoverFilter(category: .series, genreIDs: [35], minVoteAverage: 7.5, minVoteCount: 300)),
        Mood(id: "date-night", name: "Date Night", emoji: "💜",
             movieFilter: DiscoverFilter(category: .movie, genreIDs: [10749, 35], minVoteAverage: 6.5, minVoteCount: 300),
             tvFilter: nil),
        Mood(id: "family-movie", name: "Family Movie", emoji: "👨‍👩‍👧‍👦",
             movieFilter: DiscoverFilter(category: .movie, genreIDs: [10751, 16], minVoteAverage: 6.5, minVoteCount: 300),
             tvFilter: nil),
        Mood(id: "hidden-gems", name: "Hidden Gems", emoji: "💎",
             movieFilter: DiscoverFilter(category: .movie, minVoteAverage: 7.2, minVoteCount: 50, maxVoteCount: 500, sortBy: "vote_average.desc"),
             tvFilter: DiscoverFilter(category: .series, minVoteAverage: 7.5, minVoteCount: 30, maxVoteCount: 300, sortBy: "vote_average.desc")),
        Mood(id: "scary", name: "Scary", emoji: "👻",
             movieFilter: DiscoverFilter(category: .movie, genreIDs: [27], minVoteAverage: 6.0, minVoteCount: 300),
             tvFilter: nil),
        Mood(id: "emotional", name: "Emotional", emoji: "😭",
             movieFilter: DiscoverFilter(category: .movie, genreIDs: [18], minVoteAverage: 7.3, minVoteCount: 500),
             tvFilter: DiscoverFilter(category: .series, genreIDs: [18], minVoteAverage: 7.8, minVoteCount: 200)),
        Mood(id: "fast-paced", name: "Fast-Paced", emoji: "⚡️",
             movieFilter: DiscoverFilter(category: .movie, genreIDs: [28, 53], minVoteAverage: 6.5, minVoteCount: 400, maxRuntime: 115),
             tvFilter: nil),
        Mood(id: "epic-adventure", name: "Epic Adventure", emoji: "🗺️",
             movieFilter: DiscoverFilter(category: .movie, genreIDs: [12, 14], minVoteAverage: 7.0, minVoteCount: 800, minRuntime: 120),
             tvFilter: DiscoverFilter(category: .series, genreIDs: [10759, 10765], minVoteAverage: 7.5, minVoteCount: 200)),
        Mood(id: "crime", name: "Crime", emoji: "🕵️",
             movieFilter: DiscoverFilter(category: .movie, genreIDs: [80], minVoteAverage: 6.8, minVoteCount: 400),
             tvFilter: DiscoverFilter(category: .series, genreIDs: [80], minVoteAverage: 7.3, minVoteCount: 200)),
        Mood(id: "mystery", name: "Mystery", emoji: "🧩",
             movieFilter: DiscoverFilter(category: .movie, genreIDs: [9648], minVoteAverage: 6.8, minVoteCount: 300),
             tvFilter: DiscoverFilter(category: .series, genreIDs: [9648], minVoteAverage: 7.3, minVoteCount: 150)),
        Mood(id: "sci-fi", name: "Sci-Fi", emoji: "🚀",
             movieFilter: DiscoverFilter(category: .movie, genreIDs: [878], minVoteAverage: 6.5, minVoteCount: 400),
             tvFilter: DiscoverFilter(category: .series, genreIDs: [10765], minVoteAverage: 7.3, minVoteCount: 200)),
        Mood(id: "fantasy", name: "Fantasy", emoji: "🐉",
             movieFilter: DiscoverFilter(category: .movie, genreIDs: [14], minVoteAverage: 6.5, minVoteCount: 400),
             tvFilter: DiscoverFilter(category: .series, genreIDs: [10765], minVoteAverage: 7.3, minVoteCount: 200)),
        Mood(id: "weekend-binge", name: "Weekend Binge", emoji: "📺",
             movieFilter: nil,
             tvFilter: DiscoverFilter(category: .series, minVoteAverage: 7.5, minVoteCount: 500)),
        Mood(id: "comfort-show", name: "Comfort Show", emoji: "☕️",
             movieFilter: nil,
             tvFilter: DiscoverFilter(category: .series, genreIDs: [35], minVoteAverage: 7.5, minVoteCount: 400))
    ]
}
