//
//  TMDBService.swift
//  NebRatings
//
//  Created by Cole Whaley on 11/29/25.
//

import Foundation

protocol CatalogService {
    func fetchShows() async throws -> [Show]
}

struct TMDBService: CatalogService {
    func fetchShows() async throws -> [Show] {
        // TODO: Replace with TMDB API integration.
        // This stub makes it easy to swap in real data later.
        return Show.sampleData
    }
}

