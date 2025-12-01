//
//  TMDBService.swift
//  NebRatings
//
//  Created by Cole Whaley on 11/29/25.
//

import Foundation

protocol CatalogService {
    func searchShows(query: String, category: Show.Category?) async throws -> [Show]
    func fetchShowDetails(id: String, category: Show.Category) async throws -> Show?
}

struct TMDBService: CatalogService {
    private let baseURL = "https://api.themoviedb.org/3"
    private let imageBaseURL = "https://image.tmdb.org/t/p"
    
    private var apiKey: String {
        Bundle.main.object(forInfoDictionaryKey: "TMDB_API_KEY") as? String ?? ""
    }
    
    init() {}
    
    private func posterURL(from path: String?) -> String? {
        guard let path = path, !path.isEmpty else { return nil }
        return "\(imageBaseURL)/w500\(path)"
    }
    
    private func backdropURL(from path: String?) -> String? {
        guard let path = path, !path.isEmpty else { return nil }
        return "\(imageBaseURL)/w780\(path)"
    }
    
    private func thumbnailURL(from path: String?) -> String? {
        guard let path = path, !path.isEmpty else { return nil }
        return "\(imageBaseURL)/w185\(path)"
    }
    
    func searchShows(query: String, category: Show.Category?) async throws -> [Show] {
        guard !query.isEmpty else { return [] }
        guard !apiKey.isEmpty else {
            throw TMDBError.missingAPIKey
        }
        
        var shows: [Show] = []
        
        // Search movies if category is nil or movie
        if category == nil || category == .movie {
            do {
                let movies = try await searchMovies(query: query)
                shows.append(contentsOf: movies)
            } catch {
                print("Error searching movies: \(error)")
                // Continue to try TV shows even if movies fail
            }
        }
        
        // Search TV shows if category is nil or series
        if category == nil || category == .series {
            do {
                let tvShows = try await searchTVShows(query: query)
                shows.append(contentsOf: tvShows)
            } catch {
                print("Error searching TV shows: \(error)")
                // If we're searching for a specific category and it fails, re-throw
                if category == .series {
                    throw error
                }
            }
        }
        
        // Sort by popularity (descending) when showing "All" categories
        if category == nil {
            shows.sort { $0.popularity > $1.popularity }
        }
        
        return shows
    }
    
    private func searchMovies(query: String) async throws -> [Show] {
        guard var urlComponents = URLComponents(string: "\(baseURL)/search/movie") else {
            throw TMDBError.invalidURL
        }
        
        urlComponents.queryItems = [
            URLQueryItem(name: "api_key", value: apiKey),
            URLQueryItem(name: "query", value: query),
            URLQueryItem(name: "include_adult", value: "false")
        ]
        
        guard let url = urlComponents.url else {
            throw TMDBError.invalidURL
        }
        
        let (data, response) = try await URLSession.shared.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw TMDBError.invalidResponse
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            print("TMDB API Error: Status code \(httpResponse.statusCode)")
            if let errorString = String(data: data, encoding: .utf8) {
                print("Response: \(errorString)")
            }
            throw TMDBError.invalidResponse
        }
        
        do {
            let movieResponse = try JSONDecoder().decode(MovieResponse.self, from: data)
            return movieResponse.results.map { convertMovieToShow($0) }
        } catch {
            print("Decoding error: \(error)")
            if let errorString = String(data: data, encoding: .utf8) {
                print("Response data: \(errorString.prefix(500))")
            }
            throw TMDBError.decodingError
        }
    }
    
    private func searchTVShows(query: String) async throws -> [Show] {
        guard var urlComponents = URLComponents(string: "\(baseURL)/search/tv") else {
            throw TMDBError.invalidURL
        }
        
        urlComponents.queryItems = [
            URLQueryItem(name: "api_key", value: apiKey),
            URLQueryItem(name: "query", value: query),
            URLQueryItem(name: "include_adult", value: "false")
        ]
        
        guard let url = urlComponents.url else {
            throw TMDBError.invalidURL
        }
        
        let (data, response) = try await URLSession.shared.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw TMDBError.invalidResponse
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            print("TMDB API Error: Status code \(httpResponse.statusCode)")
            if let errorString = String(data: data, encoding: .utf8) {
                print("Response: \(errorString)")
            }
            throw TMDBError.invalidResponse
        }
        
        do {
            let tvResponse = try JSONDecoder().decode(TVResponse.self, from: data)
            return tvResponse.results.map { convertTVToShow($0) }
        } catch {
            print("Decoding error: \(error)")
            if let errorString = String(data: data, encoding: .utf8) {
                print("Response data: \(errorString.prefix(500))")
            }
            throw TMDBError.decodingError
        }
    }
    
    func fetchShowDetails(id: String, category: Show.Category) async throws -> Show? {
        guard !apiKey.isEmpty else {
            throw TMDBError.missingAPIKey
        }
        
        switch category {
        case .movie:
            return try await fetchMovieDetails(id: id)
        case .series:
            return try await fetchTVDetails(id: id)
        }
    }
    
    private func fetchMovieDetails(id: String) async throws -> Show? {
        guard var urlComponents = URLComponents(string: "\(baseURL)/movie/\(id)") else {
            throw TMDBError.invalidURL
        }
        
        urlComponents.queryItems = [
            URLQueryItem(name: "api_key", value: apiKey)
        ]
        
        guard let url = urlComponents.url else {
            throw TMDBError.invalidURL
        }
        
        let (data, response) = try await URLSession.shared.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw TMDBError.invalidResponse
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            throw TMDBError.invalidResponse
        }
        
        do {
            let movieDetails = try JSONDecoder().decode(MovieDetailsResponse.self, from: data)
            return convertMovieDetailsToShow(movieDetails)
        } catch {
            print("Decoding error: \(error)")
            throw TMDBError.decodingError
        }
    }
    
    private func fetchTVDetails(id: String) async throws -> Show? {
        guard var urlComponents = URLComponents(string: "\(baseURL)/tv/\(id)") else {
            throw TMDBError.invalidURL
        }
        
        urlComponents.queryItems = [
            URLQueryItem(name: "api_key", value: apiKey)
        ]
        
        guard let url = urlComponents.url else {
            throw TMDBError.invalidURL
        }
        
        let (data, response) = try await URLSession.shared.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw TMDBError.invalidResponse
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            throw TMDBError.invalidResponse
        }
        
        do {
            let tvDetails = try JSONDecoder().decode(TVDetailsResponse.self, from: data)
            return convertTVDetailsToShow(tvDetails)
        } catch {
            print("Decoding error: \(error)")
            throw TMDBError.decodingError
        }
    }
    
    // MARK: - Conversion Helpers
    
    private func convertMovieToShow(_ movie: TMDBMovie) -> Show {
        let year = extractYear(from: movie.releaseDate)
        return Show(
            id: UUID(), // We'll use TMDB ID mapping in the future
            title: movie.title,
            category: .movie,
            year: year,
            synopsis: movie.overview.isEmpty ? "No description available" : movie.overview,
            tagline: movie.overview.isEmpty ? "" : String(movie.overview.prefix(100)),
            streamingService: "TMDB",
            posterURL: posterURL(from: movie.posterPath),
            backdropURL: backdropURL(from: movie.backdropPath),
            popularity: movie.popularity ?? 0.0
        )
    }
    
    private func convertTVToShow(_ tv: TMDBTV) -> Show {
        let year = extractYear(from: tv.firstAirDate)
        return Show(
            id: UUID(), // We'll use TMDB ID mapping in the future
            title: tv.name,
            category: .series,
            year: year,
            synopsis: tv.overview.isEmpty ? "No description available" : tv.overview,
            tagline: tv.overview.isEmpty ? "" : String(tv.overview.prefix(100)),
            streamingService: "TMDB",
            posterURL: posterURL(from: tv.posterPath),
            backdropURL: backdropURL(from: tv.backdropPath),
            popularity: tv.popularity ?? 0.0
        )
    }
    
    private func convertMovieDetailsToShow(_ details: MovieDetailsResponse) -> Show {
        let year = extractYear(from: details.releaseDate)
        return Show(
            id: UUID(),
            title: details.title,
            category: .movie,
            year: year,
            synopsis: details.overview.isEmpty ? "No description available" : details.overview,
            tagline: details.tagline ?? String(details.overview.prefix(100)),
            streamingService: "TMDB",
            posterURL: posterURL(from: details.posterPath),
            backdropURL: backdropURL(from: details.backdropPath),
            popularity: 0.0 // Details endpoint doesn't include popularity
        )
    }
    
    private func convertTVDetailsToShow(_ details: TVDetailsResponse) -> Show {
        let year = extractYear(from: details.firstAirDate)
        return Show(
            id: UUID(),
            title: details.name,
            category: .series,
            year: year,
            synopsis: details.overview.isEmpty ? "No description available" : details.overview,
            tagline: details.tagline ?? String(details.overview.prefix(100)),
            streamingService: "TMDB",
            posterURL: posterURL(from: details.posterPath),
            backdropURL: backdropURL(from: details.backdropPath),
            popularity: 0.0 // Details endpoint doesn't include popularity
        )
    }
    
    private func extractYear(from dateString: String?) -> Int {
        guard let dateString = dateString, dateString.count >= 4 else {
            return Calendar.current.component(.year, from: Date())
        }
        let yearString = String(dateString.prefix(4))
        return Int(yearString) ?? Calendar.current.component(.year, from: Date())
    }
}

// MARK: - TMDB Errors

enum TMDBError: LocalizedError {
    case missingAPIKey
    case invalidURL
    case invalidResponse
    case decodingError
    
    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "TMDB API key is missing. Please add TMDB_API_KEY to Info.plist"
        case .invalidURL:
            return "Invalid URL for TMDB API request"
        case .invalidResponse:
            return "Invalid response from TMDB API"
        case .decodingError:
            return "Failed to decode TMDB API response"
        }
    }
}


