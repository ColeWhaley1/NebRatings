//
//  TMDBService.swift
//  NebRatings
//
//  Created by Cole Whaley on 11/29/25.
//

import Foundation

protocol CatalogService {
    func searchShows(query: String) async throws -> [Show]
    func fetchShowDetails(id: String) async throws -> Show?
}

struct TMDBService: CatalogService {
    private let apiKey: String
    private let baseURL = "https://api.themoviedb.org/3"
    
    init(apiKey: String = "") {
        self.apiKey = apiKey
        // TODO: Load API key from environment or config
    }
    
    func searchShows(query: String) async throws -> [Show] {
        guard !query.isEmpty else { return [] }
        
        let apiKey = Bundle.main.object(forInfoDictionaryKey: "TMDB_API_KEY") as? String
        let url = URL(string: "https://api.themoviedb.org/3/search/movie?query=\(query)&api_key=\(apiKey!)")!

        let (data, _) = try await URLSession.shared.data(from: url)
        let decoded = try JSONDecoder().decode(MovieResponse.self, from: data)
        return decoded.results
        
        // TODO: Replace with actual TMDB API calls
        // Example structure:
        // let url = URL(string: "\(baseURL)/search/multi?api_key=\(apiKey)&query=\(query)")!
        // let (data, _) = try await URLSession.shared.data(from: url)
        // let response = try JSONDecoder().decode(TMDBSearchResponse.self, from: data)
        // return response.results.map { convertToShow($0) }
        
        // For now, return filtered sample data based on query
        return Show.sampleData.filter { $0.matches(query) }
    }
    
    func fetchShowDetails(id: String) async throws -> Show? {
        // TODO: Implement TMDB API call to fetch show details by ID
        // Example: GET /movie/{movie_id} or /tv/{tv_id}
        return Show.sampleData.first(where: { $0.id.uuidString == id })
    }
}

