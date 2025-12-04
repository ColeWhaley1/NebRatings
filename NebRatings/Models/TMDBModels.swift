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
    
    enum CodingKeys: String, CodingKey {
        case id, title, overview, popularity
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
    
    enum CodingKeys: String, CodingKey {
        case id, name, overview, popularity
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
    
    enum CodingKeys: String, CodingKey {
        case id, title, overview, tagline, genres
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
    
    enum CodingKeys: String, CodingKey {
        case id, name, overview, tagline, genres
        case firstAirDate = "first_air_date"
        case posterPath = "poster_path"
        case backdropPath = "backdrop_path"
        case voteAverage = "vote_average"
        case voteCount = "vote_count"
    }
}

