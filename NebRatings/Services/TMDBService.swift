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
    func fetchTrendingShows(category: Show.Category?) async throws -> [Show]
    func fetchRecommendations(tmdbID: Int, category: Show.Category) async throws -> [Show]
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
            // Fetch watch providers
            let watchProviders = try? await fetchWatchProviders(tmdbID: movieDetails.id, category: .movie)
            return convertMovieDetailsToShow(movieDetails, watchProviders: watchProviders ?? [])
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
            // Fetch watch providers
            let watchProviders = try? await fetchWatchProviders(tmdbID: tvDetails.id, category: .series)
            return convertTVDetailsToShow(tvDetails, watchProviders: watchProviders ?? [])
        } catch {
            print("Decoding error: \(error)")
            throw TMDBError.decodingError
        }
    }
    
    private func providerLogoURL(from path: String?) -> String? {
        guard let path = path, !path.isEmpty else { return nil }
        return "\(imageBaseURL)/w45\(path)"
    }
    
    private func cleanProviderName(_ name: String) -> String {
        // Remove subscription tier information and channel/distribution suffixes
        // Preserve base service names like "Disney Plus", "Paramount Plus"
        // Examples: 
        //   "Netflix Standard with Ads" -> "Netflix"
        //   "Paramount Plus Standard" -> "Paramount Plus"
        //   "Paramount Plus Apple TV Channel" -> "Paramount Plus"
        var cleaned = name.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // First, remove channel/distribution method suffixes (order matters - more specific first)
        let channelPatterns = [
            " Apple TV Channel",
            " Channel",
            " via Apple TV Channel",
            " via Prime Video",
            " via Roku Channel",
            " via YouTube",
            " via Google Play"
        ]
        
        for pattern in channelPatterns {
            if cleaned.hasSuffix(pattern) {
                cleaned = String(cleaned.dropLast(pattern.count))
                break
            }
        }
        
        // Then remove subscription tier suffixes (order matters - more specific first)
        let tierPatterns = [
            " Standard with Ads",
            " Premium with Ads",
            " Basic with Ads",
            " Standard",
            " Premium",
            " Basic",
            " with Ads",
            " (Ads)",
            " (No Ads)",
            " (4K)",
            " (HD)",
            " (SD)",
            " (UHD)",
            " (Free)",
            " (Subscription)",
            " (Rent)",
            " (Buy)"
        ]
        
        for pattern in tierPatterns {
            if cleaned.hasSuffix(pattern) {
                cleaned = String(cleaned.dropLast(pattern.count))
                break // Only remove one pattern
            }
        }
        
        // Trim again after removing patterns
        return cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    private func fetchWatchProviders(tmdbID: Int, category: Show.Category) async throws -> [WatchProviderInfo] {
        let endpoint = category == .movie ? "movie" : "tv"
        guard var urlComponents = URLComponents(string: "\(baseURL)/\(endpoint)/\(tmdbID)/watch/providers") else {
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
            let providersResponse = try JSONDecoder().decode(WatchProvidersResponse.self, from: data)
            // Get US providers (or first available country)
            var providers: [WatchProviderInfo] = []
            var seenNames = Set<String>()
            
            // Try US first, then any available country
            let countryProviders = providersResponse.results?["US"] ?? providersResponse.results?.values.first
            
            if let flatrate = countryProviders?.flatrate {
                for provider in flatrate {
                    let cleanedName = cleanProviderName(provider.providerName)
                    // Only add if we haven't seen this base name before (deduplicate)
                    if !seenNames.contains(cleanedName) {
                        seenNames.insert(cleanedName)
                        providers.append(WatchProviderInfo(
                            id: provider.providerId,
                            name: cleanedName,
                            logoURL: providerLogoURL(from: provider.logoPath)
                        ))
                    }
                }
            }
            
            return providers
        } catch {
            print("Error decoding watch providers: \(error)")
            return []
        }
    }
    
    // MARK: - Conversion Helpers
    
    private func convertMovieToShow(_ movie: TMDBMovie) -> Show {
        let year = extractYear(from: movie.releaseDate)
        return Show(
            id: movie.id,  // Use TMDB ID directly
            title: movie.title,
            category: .movie,
            year: year,
            synopsis: movie.overview.isEmpty ? "No description available" : movie.overview,
            tagline: movie.overview.isEmpty ? "" : String(movie.overview.prefix(100)),
            streamingService: "Various",
            posterURL: posterURL(from: movie.posterPath),
            backdropURL: backdropURL(from: movie.backdropPath),
            popularity: movie.popularity ?? 0.0,
            genres: [], // Search results don't include genre names, only IDs
            rating: movie.voteAverage,
            watchProviders: [] // Search results don't include watch providers
        )
    }
    
    private func convertTVToShow(_ tv: TMDBTV) -> Show {
        let year = extractYear(from: tv.firstAirDate)
        return Show(
            id: tv.id,  // Use TMDB ID directly
            title: tv.name,
            category: .series,
            year: year,
            synopsis: tv.overview.isEmpty ? "No description available" : tv.overview,
            tagline: tv.overview.isEmpty ? "" : String(tv.overview.prefix(100)),
            streamingService: "Various",
            posterURL: posterURL(from: tv.posterPath),
            backdropURL: backdropURL(from: tv.backdropPath),
            popularity: tv.popularity ?? 0.0,
            genres: [], // Search results don't include genre names, only IDs
            rating: tv.voteAverage,
            watchProviders: [] // Search results don't include watch providers
        )
    }
    
    private func convertMovieDetailsToShow(_ details: MovieDetailsResponse, watchProviders: [WatchProviderInfo] = []) -> Show {
        let year = extractYear(from: details.releaseDate)
        let genreNames = details.genres?.map { $0.name } ?? []
        let primaryProvider = watchProviders.first?.name ?? "Various"
        return Show(
            id: details.id,  // Use TMDB ID directly
            title: details.title,
            category: .movie,
            year: year,
            synopsis: details.overview.isEmpty ? "No description available" : details.overview,
            tagline: details.tagline ?? String(details.overview.prefix(100)),
            streamingService: primaryProvider,
            posterURL: posterURL(from: details.posterPath),
            backdropURL: backdropURL(from: details.backdropPath),
            popularity: 0.0, // Details endpoint doesn't include popularity
            genres: genreNames,
            rating: details.voteAverage,
            watchProviders: watchProviders
        )
    }
    
    private func convertTVDetailsToShow(_ details: TVDetailsResponse, watchProviders: [WatchProviderInfo] = []) -> Show {
        let year = extractYear(from: details.firstAirDate)
        let genreNames = details.genres?.map { $0.name } ?? []
        let primaryProvider = watchProviders.first?.name ?? "Various"
        return Show(
            id: details.id,  // Use TMDB ID directly
            title: details.name,
            category: .series,
            year: year,
            synopsis: details.overview.isEmpty ? "No description available" : details.overview,
            tagline: details.tagline ?? String(details.overview.prefix(100)),
            streamingService: primaryProvider,
            posterURL: posterURL(from: details.posterPath),
            backdropURL: backdropURL(from: details.backdropPath),
            popularity: 0.0, // Details endpoint doesn't include popularity
            genres: genreNames,
            rating: details.voteAverage,
            watchProviders: watchProviders
        )
    }
    
    func fetchTrendingShows(category: Show.Category?) async throws -> [Show] {
        guard !apiKey.isEmpty else {
            throw TMDBError.missingAPIKey
        }
        
        var shows: [Show] = []
        
        // Fetch trending movies if category is nil or movie
        if category == nil || category == .movie {
            do {
                let movies = try await fetchTrendingMovies()
                shows.append(contentsOf: movies)
            } catch {
                print("Error fetching trending movies: \(error)")
                // Continue to try TV shows even if movies fail
            }
        }
        
        // Fetch trending TV shows if category is nil or series
        if category == nil || category == .series {
            do {
                let tvShows = try await fetchTrendingTVShows()
                shows.append(contentsOf: tvShows)
            } catch {
                print("Error fetching trending TV shows: \(error)")
                // If we're fetching for a specific category and it fails, re-throw
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
    
    private func fetchTrendingMovies() async throws -> [Show] {
        guard var urlComponents = URLComponents(string: "\(baseURL)/trending/movie/day") else {
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
    
    private func fetchTrendingTVShows() async throws -> [Show] {
        guard var urlComponents = URLComponents(string: "\(baseURL)/trending/tv/day") else {
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
    
    func fetchRecommendations(tmdbID: Int, category: Show.Category) async throws -> [Show] {
        guard !apiKey.isEmpty else {
            throw TMDBError.missingAPIKey
        }
        
        switch category {
        case .movie:
            return try await fetchMovieRecommendations(tmdbID: tmdbID)
        case .series:
            return try await fetchTVRecommendations(tmdbID: tmdbID)
        }
    }
    
    private func fetchMovieRecommendations(tmdbID: Int) async throws -> [Show] {
        guard var urlComponents = URLComponents(string: "\(baseURL)/movie/\(tmdbID)/recommendations") else {
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
    
    private func fetchTVRecommendations(tmdbID: Int) async throws -> [Show] {
        guard var urlComponents = URLComponents(string: "\(baseURL)/tv/\(tmdbID)/recommendations") else {
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


