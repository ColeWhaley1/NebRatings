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
    func fetchTrailers(tmdbID: Int, category: Show.Category) async throws -> [Trailer]
    /// TMDB /discover with the given filter (one medium per call).
    func fetchDiscover(filter: DiscoverFilter) async throws -> [Show]
    /// Weekly trending window (the existing fetchTrendingShows is daily).
    func fetchTrendingWeekShows(category: Show.Category?) async throws -> [Show]
    /// Resolves keyword names to TMDB keyword IDs (top match each).
    func fetchKeywordIDs(names: [String]) async throws -> [Int]
    /// Top-billed cast with headshot URLs (fetched on demand).
    func fetchCast(tmdbID: Int, category: Show.Category) async throws -> [CastMember]
    /// Every movie/TV title a person acted in (combined credits).
    func fetchPersonFilmography(personID: Int) async throws -> [Show]
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
                // Continue to try TV shows even if movies fail
            }
        }
        
        // Search TV shows if category is nil or series
        if category == nil || category == .series {
            do {
                let tvShows = try await searchTVShows(query: query)
                shows.append(contentsOf: tvShows)
            } catch {
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
            if let errorString = String(data: data, encoding: .utf8) {
            }
            throw TMDBError.invalidResponse
        }
        
        do {
            let movieResponse = try JSONDecoder().decode(MovieResponse.self, from: data)
            return movieResponse.results.filter { !($0.adult ?? false) }.map { convertMovieToShow($0) }
        } catch {
            if let errorString = String(data: data, encoding: .utf8) {
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
            if let errorString = String(data: data, encoding: .utf8) {
            }
            throw TMDBError.invalidResponse
        }
        
        do {
            let tvResponse = try JSONDecoder().decode(TVResponse.self, from: data)
            return tvResponse.results.filter { !($0.adult ?? false) }.map { convertTVToShow($0) }
        } catch {
            if let errorString = String(data: data, encoding: .utf8) {
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
            // Hard block: never surface pornographic titles, even via a
            // direct/deep-link fetch to a specific id.
            if movieDetails.adult == true { return nil }
            // Fetch watch providers
            let watchProviders = try? await fetchWatchProviders(tmdbID: movieDetails.id, category: .movie)
            return convertMovieDetailsToShow(movieDetails, watchProviders: watchProviders ?? [])
        } catch {
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
            // Hard block pornographic titles even on a direct fetch.
            if tvDetails.adult == true { return nil }
            // Fetch watch providers
            let watchProviders = try? await fetchWatchProviders(tmdbID: tvDetails.id, category: .series)
            return convertTVDetailsToShow(tvDetails, watchProviders: watchProviders ?? [])
        } catch {
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
            // List endpoints return only genre_ids — resolve to names via
            // the static catalog so recommendation scoring has genres.
            genres: GenreCatalog.names(forGenreIDs: movie.genreIds),
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
            genres: GenreCatalog.names(forGenreIDs: tv.genreIds),
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
            watchProviders: watchProviders,
            numberOfSeasons: details.numberOfSeasons
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
                // Continue to try TV shows even if movies fail
            }
        }
        
        // Fetch trending TV shows if category is nil or series
        if category == nil || category == .series {
            do {
                let tvShows = try await fetchTrendingTVShows()
                shows.append(contentsOf: tvShows)
            } catch {
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
            if let errorString = String(data: data, encoding: .utf8) {
            }
            throw TMDBError.invalidResponse
        }
        
        do {
            let movieResponse = try JSONDecoder().decode(MovieResponse.self, from: data)
            return movieResponse.results.filter { !($0.adult ?? false) }.map { convertMovieToShow($0) }
        } catch {
            if let errorString = String(data: data, encoding: .utf8) {
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
            if let errorString = String(data: data, encoding: .utf8) {
            }
            throw TMDBError.invalidResponse
        }
        
        do {
            let tvResponse = try JSONDecoder().decode(TVResponse.self, from: data)
            return tvResponse.results.filter { !($0.adult ?? false) }.map { convertTVToShow($0) }
        } catch {
            if let errorString = String(data: data, encoding: .utf8) {
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
            if let errorString = String(data: data, encoding: .utf8) {
            }
            throw TMDBError.invalidResponse
        }
        
        do {
            let movieResponse = try JSONDecoder().decode(MovieResponse.self, from: data)
            return movieResponse.results.filter { !($0.adult ?? false) }.map { convertMovieToShow($0) }
        } catch {
            if let errorString = String(data: data, encoding: .utf8) {
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
            if let errorString = String(data: data, encoding: .utf8) {
            }
            throw TMDBError.invalidResponse
        }
        
        do {
            let tvResponse = try JSONDecoder().decode(TVResponse.self, from: data)
            return tvResponse.results.filter { !($0.adult ?? false) }.map { convertTVToShow($0) }
        } catch {
            if let errorString = String(data: data, encoding: .utf8) {
            }
            throw TMDBError.decodingError
        }
    }
    
    // MARK: - Discover / curated lists

    /// Generic "fetch a list of shows from a TMDB endpoint" helper — all the
    /// curated-section endpoints share this decode/convert path.
    private func fetchShowList(path: String, extraQueryItems: [URLQueryItem] = [], isMovie: Bool) async throws -> [Show] {
        guard !apiKey.isEmpty else {
            throw TMDBError.missingAPIKey
        }
        guard var urlComponents = URLComponents(string: "\(baseURL)/\(path)") else {
            throw TMDBError.invalidURL
        }
        urlComponents.queryItems = [
            URLQueryItem(name: "api_key", value: apiKey),
            URLQueryItem(name: "include_adult", value: "false")
        ] + extraQueryItems
        guard let url = urlComponents.url else {
            throw TMDBError.invalidURL
        }

        let (data, response) = try await URLSession.shared.data(from: url)
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw TMDBError.invalidResponse
        }

        do {
            if isMovie {
                let movieResponse = try JSONDecoder().decode(MovieResponse.self, from: data)
                return movieResponse.results.filter { !($0.adult ?? false) }.map { convertMovieToShow($0) }
            } else {
                let tvResponse = try JSONDecoder().decode(TVResponse.self, from: data)
                return tvResponse.results.filter { !($0.adult ?? false) }.map { convertTVToShow($0) }
            }
        } catch {
            throw TMDBError.decodingError
        }
    }

    func fetchDiscover(filter: DiscoverFilter) async throws -> [Show] {
        let isMovie = filter.category == .movie
        var items: [URLQueryItem] = [
            URLQueryItem(name: "sort_by", value: filter.sortBy),
            // Guard rail: unrated obscurities dominate vote_average sorts
            // without a floor.
            URLQueryItem(name: "vote_count.gte", value: String(filter.minVoteCount ?? 20))
        ]
        if isMovie, let certificationCap = filter.movieCertificationCap {
            // Content-preference ceiling (e.g. PG for Family Friendly,
            // PG-13 for General Audience). TMDB only supports certification
            // filters on movies; TV filtering happens through genre
            // exclusions below plus the include_adult base parameter.
            items.append(URLQueryItem(name: "certification_country", value: "US"))
            items.append(URLQueryItem(name: "certification.lte", value: certificationCap))
        }
        if !filter.excludedGenreIDs.isEmpty {
            items.append(URLQueryItem(name: "without_genres", value: filter.excludedGenreIDs.map(String.init).joined(separator: ",")))
        }
        if !filter.genreIDs.isEmpty {
            // TMDB: comma = AND, pipe = OR.
            let separator = filter.genreMatch == .any ? "|" : ","
            items.append(URLQueryItem(name: "with_genres", value: filter.genreIDs.map(String.init).joined(separator: separator)))
        }
        if !filter.keywordIDs.isEmpty {
            // Keywords OR-ed: any matching keyword qualifies.
            items.append(URLQueryItem(name: "with_keywords", value: filter.keywordIDs.map(String.init).joined(separator: "|")))
        }
        if let minVoteAverage = filter.minVoteAverage {
            items.append(URLQueryItem(name: "vote_average.gte", value: String(minVoteAverage)))
        }
        if let maxVoteCount = filter.maxVoteCount {
            items.append(URLQueryItem(name: "vote_count.lte", value: String(maxVoteCount)))
        }
        if let minRuntime = filter.minRuntime {
            items.append(URLQueryItem(name: "with_runtime.gte", value: String(minRuntime)))
        }
        if let maxRuntime = filter.maxRuntime {
            items.append(URLQueryItem(name: "with_runtime.lte", value: String(maxRuntime)))
        }

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let dateField = isMovie ? "primary_release_date" : "first_air_date"
        if let after = filter.releasedAfter {
            items.append(URLQueryItem(name: "\(dateField).gte", value: dateFormatter.string(from: after)))
        }
        if let before = filter.releasedBefore {
            items.append(URLQueryItem(name: "\(dateField).lte", value: dateFormatter.string(from: before)))
        }

        return try await fetchShowList(
            path: isMovie ? "discover/movie" : "discover/tv",
            extraQueryItems: items,
            isMovie: isMovie
        )
    }

    /// Resolves human-readable keyword names ("christmas", "beach") to TMDB
    /// keyword IDs via /search/keyword, taking the top match per name.
    /// Names with no match are silently skipped.
    func fetchKeywordIDs(names: [String]) async throws -> [Int] {
        guard !apiKey.isEmpty else {
            throw TMDBError.missingAPIKey
        }
        var ids: [Int] = []
        for name in names {
            guard var urlComponents = URLComponents(string: "\(baseURL)/search/keyword") else { continue }
            urlComponents.queryItems = [
                URLQueryItem(name: "api_key", value: apiKey),
                URLQueryItem(name: "query", value: name)
            ]
            guard let url = urlComponents.url,
                  let (data, response) = try? await URLSession.shared.data(from: url),
                  let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode),
                  let decoded = try? JSONDecoder().decode(KeywordSearchResponse.self, from: data),
                  let first = decoded.results.first
            else { continue }
            ids.append(first.id)
        }
        return ids
    }

    func fetchTrendingWeekShows(category: Show.Category?) async throws -> [Show] {
        var shows: [Show] = []
        if category == nil || category == .movie {
            shows += (try? await fetchShowList(path: "trending/movie/week", isMovie: true)) ?? []
        }
        if category == nil || category == .series {
            shows += (try? await fetchShowList(path: "trending/tv/week", isMovie: false)) ?? []
        }
        if category == nil {
            shows.sort { $0.popularity > $1.popularity }
        }
        return shows
    }

    // MARK: - Cast

    /// /movie/{id}/credits or /tv/{id}/credits — top-billed cast, billing
    /// order preserved, capped at 24 so ensemble shows don't dump hundreds
    /// of one-line roles.
    func fetchCast(tmdbID: Int, category: Show.Category) async throws -> [CastMember] {
        guard !apiKey.isEmpty else {
            throw TMDBError.missingAPIKey
        }
        let endpoint = category == .movie ? "movie" : "tv"
        guard var urlComponents = URLComponents(string: "\(baseURL)/\(endpoint)/\(tmdbID)/credits") else {
            throw TMDBError.invalidURL
        }
        urlComponents.queryItems = [
            URLQueryItem(name: "api_key", value: apiKey)
        ]
        guard let url = urlComponents.url else {
            throw TMDBError.invalidURL
        }

        let (data, response) = try await URLSession.shared.data(from: url)
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw TMDBError.invalidResponse
        }

        do {
            let credits = try JSONDecoder().decode(CreditsResponse.self, from: data)
            return credits.cast
                .sorted { ($0.order ?? Int.max) < ($1.order ?? Int.max) }
                .prefix(24)
                .map { member in
                    CastMember(
                        id: member.id,
                        name: member.name,
                        character: member.character,
                        profileURL: thumbnailURL(from: member.profilePath),
                        order: member.order ?? Int.max
                    )
                }
        } catch {
            throw TMDBError.decodingError
        }
    }

    // MARK: - Person filmography

    /// /person/{id}/combined_credits — the titles an actor acted in, converted
    /// to `Show`s. De-duped by id (a person can be credited more than once on a
    /// single title), sorted most-popular first, and capped so a prolific
    /// actor's page stays browsable rather than dumping hundreds of bit parts.
    func fetchPersonFilmography(personID: Int) async throws -> [Show] {
        guard !apiKey.isEmpty else {
            throw TMDBError.missingAPIKey
        }
        guard var urlComponents = URLComponents(string: "\(baseURL)/person/\(personID)/combined_credits") else {
            throw TMDBError.invalidURL
        }
        urlComponents.queryItems = [
            URLQueryItem(name: "api_key", value: apiKey)
        ]
        guard let url = urlComponents.url else {
            throw TMDBError.invalidURL
        }

        let (data, response) = try await URLSession.shared.data(from: url)
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw TMDBError.invalidResponse
        }

        do {
            let credits = try JSONDecoder().decode(PersonCreditsResponse.self, from: data)
            var seenIDs = Set<Int>()
            return credits.cast
                .compactMap { convertPersonCreditToShow($0) }
                .filter { seenIDs.insert($0.id).inserted }
                .sorted { $0.popularity > $1.popularity }
                .prefix(40)
                .map { $0 }
        } catch {
            throw TMDBError.decodingError
        }
    }

    /// Converts one combined-credits entry to a `Show`. Returns nil for
    /// non-movie/TV media types (e.g. some person credits are miscellaneous)
    /// and hard-blocks adult titles.
    private func convertPersonCreditToShow(_ credit: PersonCredit) -> Show? {
        let isMovie = credit.mediaType == "movie"
        let isTV = credit.mediaType == "tv"
        guard isMovie || isTV else { return nil }
        if credit.adult == true { return nil }

        let title = (isMovie ? credit.title : credit.name) ?? ""
        guard !title.isEmpty else { return nil }

        let year = extractYear(from: isMovie ? credit.releaseDate : credit.firstAirDate)
        return Show(
            id: credit.id,
            title: title,
            category: isMovie ? .movie : .series,
            year: year,
            synopsis: credit.overview?.isEmpty == false ? credit.overview! : "No description available",
            tagline: "",
            streamingService: "Various",
            posterURL: posterURL(from: credit.posterPath),
            backdropURL: backdropURL(from: credit.backdropPath),
            popularity: credit.popularity ?? 0.0,
            genres: GenreCatalog.names(forGenreIDs: credit.genreIds),
            rating: credit.voteAverage
        )
    }

    // MARK: - Trailers

    /// Fetches YouTube trailers for a movie/show from TMDB's /videos endpoint.
    /// Returns only YouTube-hosted Trailers and Teasers, sorted by priority:
    /// official Trailer → any Trailer → Teaser. Non-video failures degrade to
    /// an empty list at the call site (the section simply hides).
    func fetchTrailers(tmdbID: Int, category: Show.Category) async throws -> [Trailer] {
        guard !apiKey.isEmpty else {
            throw TMDBError.missingAPIKey
        }
        let endpoint = category == .movie ? "movie" : "tv"
        guard var urlComponents = URLComponents(string: "\(baseURL)/\(endpoint)/\(tmdbID)/videos") else {
            throw TMDBError.invalidURL
        }
        urlComponents.queryItems = [
            URLQueryItem(name: "api_key", value: apiKey)
        ]
        guard let url = urlComponents.url else {
            throw TMDBError.invalidURL
        }

        let (data, response) = try await URLSession.shared.data(from: url)
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw TMDBError.invalidResponse
        }

        do {
            let videosResponse = try JSONDecoder().decode(VideosResponse.self, from: data)
            return videosResponse.results
                .filter { $0.site == "YouTube" && ($0.type == "Trailer" || $0.type == "Teaser") }
                .sorted { trailerPriority($0) < trailerPriority($1) }
                // Some titles have a dozen+ videos; three is plenty, and the
                // priority sort guarantees the official trailer leads.
                .prefix(3)
                .map { video in
                    Trailer(
                        id: video.id,
                        youtubeKey: video.key,
                        name: video.name,
                        type: video.type,
                        isOfficial: video.official ?? false
                    )
                }
        } catch {
            throw TMDBError.decodingError
        }
    }

    /// Lower = shown first. Official Trailer → Trailer → Teaser.
    private func trailerPriority(_ video: TMDBVideo) -> Int {
        switch (video.type, video.official ?? false) {
        case ("Trailer", true): return 0
        case ("Trailer", false): return 1
        default: return 2 // Teaser (official or not)
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


