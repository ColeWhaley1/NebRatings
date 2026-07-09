//
//  TMDBModels.swift
//  NebRatings
//
//  Created by Cole Whaley on 11/29/25.
//

import Foundation

// MARK: - Movie Response Models
struct MovieResponse: Codable {
    let page: Int
    let results: [TMDBMovie]
    let totalPages: Int?
    let totalResults: Int?
    
    enum CodingKeys: String, CodingKey {
        case page, results
        case totalPages = "total_pages"
        case totalResults = "total_results"
    }
}

struct TMDBMovie: Codable {
    let id: Int
    let title: String
    let overview: String
    let releaseDate: String?
    let posterPath: String?
    let backdropPath: String?
    let voteAverage: Double?
    let voteCount: Int?
    let popularity: Double?
    let genreIds: [Int]?
    /// TMDB's pornographic-content flag. We hard-drop any title where this
    /// is true, on every endpoint (belt-and-suspenders with include_adult).
    let adult: Bool?

    enum CodingKeys: String, CodingKey {
        case id, title, overview, popularity, adult
        case releaseDate = "release_date"
        case posterPath = "poster_path"
        case backdropPath = "backdrop_path"
        case voteAverage = "vote_average"
        case voteCount = "vote_count"
        case genreIds = "genre_ids"
    }
}

// MARK: - TV Show Response Models
struct TVResponse: Codable {
    let page: Int
    let results: [TMDBTV]
    let totalPages: Int?
    let totalResults: Int?
    
    enum CodingKeys: String, CodingKey {
        case page, results
        case totalPages = "total_pages"
        case totalResults = "total_results"
    }
}

struct TMDBTV: Codable {
    let id: Int
    let name: String
    let overview: String
    let firstAirDate: String?
    let posterPath: String?
    let backdropPath: String?
    let voteAverage: Double?
    let voteCount: Int?
    let popularity: Double?
    let genreIds: [Int]?
    /// TMDB's pornographic-content flag (dropped everywhere).
    let adult: Bool?

    enum CodingKeys: String, CodingKey {
        case id, name, overview, popularity, adult
        case firstAirDate = "first_air_date"
        case posterPath = "poster_path"
        case backdropPath = "backdrop_path"
        case voteAverage = "vote_average"
        case voteCount = "vote_count"
        case genreIds = "genre_ids"
    }
}

// MARK: - Genre Model
struct TMDBGenre: Codable {
    let id: Int
    let name: String
}

// MARK: - Video (Trailer) Models

struct VideosResponse: Codable {
    let id: Int?
    let results: [TMDBVideo]
}

struct TMDBVideo: Codable {
    let id: String
    let key: String
    let name: String
    let site: String
    let type: String
    let official: Bool?
    let publishedAt: String?

    enum CodingKeys: String, CodingKey {
        case id, key, name, site, type, official
        case publishedAt = "published_at"
    }
}

/// App-facing trailer, already filtered to YouTube and sorted by priority
/// (official trailer → trailer → teaser). `youtubeKey` is the YouTube video id.
struct Trailer: Identifiable, Hashable {
    let id: String
    let youtubeKey: String
    let name: String
    /// TMDB type: "Trailer" or "Teaser".
    let type: String
    let isOfficial: Bool

    /// YouTube's own thumbnail CDN — no extra TMDB call needed.
    var thumbnailURL: String {
        "https://img.youtube.com/vi/\(youtubeKey)/hqdefault.jpg"
    }

    /// Fallback: open in the YouTube app / Safari. In-app playback builds an
    /// iframe wrapper from `youtubeKey` (see YouTubeEmbedView) — loading an
    /// embed URL directly fails YouTube's origin check (error 153).
    var watchURL: URL? {
        URL(string: "https://www.youtube.com/watch?v=\(youtubeKey)")
    }
}

// MARK: - Credits (cast)

struct CreditsResponse: Codable {
    let cast: [TMDBCastMember]
}

struct TMDBCastMember: Codable {
    let id: Int
    let name: String
    let character: String?
    let profilePath: String?
    let order: Int?

    enum CodingKeys: String, CodingKey {
        case id, name, character, order
        case profilePath = "profile_path"
    }
}

/// App-facing cast member with a resolved headshot URL. Fetched on demand
/// (the cast screen), never with the detail page itself.
struct CastMember: Identifiable, Hashable {
    let id: Int
    let name: String
    let character: String?
    let profileURL: String?
    let order: Int
}

// MARK: - Keyword Search

struct KeywordSearchResponse: Codable {
    let results: [TMDBKeyword]
}

struct TMDBKeyword: Codable {
    let id: Int
    let name: String
}

// MARK: - Watch Provider Models
struct WatchProvider: Codable {
    let displayPriority: Int
    let logoPath: String?
    let providerId: Int
    let providerName: String
    
    enum CodingKeys: String, CodingKey {
        case displayPriority = "display_priority"
        case logoPath = "logo_path"
        case providerId = "provider_id"
        case providerName = "provider_name"
    }
}

struct WatchProvidersResponse: Codable {
    let results: [String: CountryWatchProviders]?
}

struct CountryWatchProviders: Codable {
    let link: String?
    let flatrate: [WatchProvider]?
    let buy: [WatchProvider]?
    let rent: [WatchProvider]?
    let free: [WatchProvider]?
    let ads: [WatchProvider]?
}

// MARK: - Movie Details Response
struct MovieDetailsResponse: Codable {
    let id: Int
    let title: String
    let overview: String
    let releaseDate: String?
    let tagline: String?
    let posterPath: String?
    let backdropPath: String?
    let voteAverage: Double?
    let voteCount: Int?
    let genres: [TMDBGenre]?
    let adult: Bool?

    enum CodingKeys: String, CodingKey {
        case id, title, overview, tagline, genres, adult
        case releaseDate = "release_date"
        case posterPath = "poster_path"
        case backdropPath = "backdrop_path"
        case voteAverage = "vote_average"
        case voteCount = "vote_count"
    }
}

// MARK: - TV Show Details Response
struct TVDetailsResponse: Codable {
    let id: Int
    let name: String
    let overview: String
    let firstAirDate: String?
    let tagline: String?
    let posterPath: String?
    let backdropPath: String?
    let voteAverage: Double?
    let voteCount: Int?
    let genres: [TMDBGenre]?
    let numberOfSeasons: Int?
    let adult: Bool?

    enum CodingKeys: String, CodingKey {
        case id, name, overview, tagline, genres, adult
        case firstAirDate = "first_air_date"
        case posterPath = "poster_path"
        case backdropPath = "backdrop_path"
        case voteAverage = "vote_average"
        case voteCount = "vote_count"
        case numberOfSeasons = "number_of_seasons"
    }
}

