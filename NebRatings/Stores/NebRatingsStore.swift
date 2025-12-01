//
//  NebRatingsStore.swift
//  NebRatings
//
//  Created by Cole Whaley on 11/29/25.
//

import Foundation

@MainActor
@Observable
final class NebRatingsStore {
    private(set) var shows: [Show] = []
    private(set) var reviews: [Review] = []
    private(set) var currentUser: UserProfile?
    private(set) var userReviews: [Review] = []
    
    private(set) var isSearchingShows = false
    private(set) var isQueryingReviews = false

    private let catalogService: CatalogService
    private let reviewService: ReviewService
    private let profileService: ProfileService
    
    // Cache for searched shows to avoid re-fetching
    private var showCache: [UUID: Show] = [:]

    init(catalogService: CatalogService = TMDBService(),
         reviewService: ReviewService = FirebaseReviewService(),
         profileService: ProfileService = FirebaseProfileService()) {
        self.catalogService = catalogService
        self.reviewService = reviewService
        self.profileService = profileService

        Task {
            await loadUserProfile()
        }
    }

    func searchShows(query: String) async {
        guard !query.isEmpty else {
            shows = []
            return
        }
        
        isSearchingShows = true
        defer { isSearchingShows = false }
        
        do {
            let results = try await catalogService.searchShows(query: query)
            shows = results
            
            // Update cache
            for show in results {
                showCache[show.id] = show
            }
        } catch {
            // Handle error - could show error state
            print("Error searching shows: \(error)")
        }
    }
    
    func queryReviews(searchText: String? = nil,
                    category: Show.Category? = nil,
                    minimumRating: Double? = nil,
                    showID: UUID? = nil) async {
        isQueryingReviews = true
        defer { isQueryingReviews = false }
        
        let query = ReviewQuery(
            searchText: searchText,
            category: category,
            minimumRating: minimumRating,
            showID: showID,
            limit: 100
        )
        
        do {
            let results = try await reviewService.queryReviews(query)
            reviews = results
        } catch {
            // Handle error
            print("Error querying reviews: \(error)")
        }
    }

    func loadUserProfile() async {
        do {
            let profile = try await profileService.fetchCurrentUser()
            currentUser = profile
            await loadUserReviews(for: profile.id)
        } catch {
            // Ignore for now and keep placeholder user nil.
        }
    }

    private func loadUserReviews(for userID: String) async {
        do {
            let reviews = try await profileService.fetchReviews(for: userID)
            userReviews = reviews
        } catch {
            // Keep existing user reviews.
        }
    }
    
    func fetchShowDetails(id: UUID) async -> Show? {
        // Check cache first
        if let cached = showCache[id] {
            return cached
        }
        
        // Fetch from API
        do {
            if let show = try await catalogService.fetchShowDetails(id: id.uuidString) {
                showCache[id] = show
                return show
            }
        } catch {
            print("Error fetching show details: \(error)")
        }
        
        return nil
    }

    func reviews(for show: Show) -> [Review] {
        reviews.filter { $0.showID == show.id }
    }

    func show(for review: Review) -> Show? {
        // Check cache first
        if let cached = showCache[review.showID] {
            return cached
        }
        
        // Check current shows list
        return shows.first(where: { $0.id == review.showID })
    }

    func addReview(author: String, comment: String, rating: Double, to show: Show) {
        let newReview = Review(showID: show.id, showTitle: show.title, author: author, comment: comment, nebRating: rating)
        
        // Add to local state immediately for optimistic UI
        reviews.insert(newReview, at: 0)
        
        // Update user reviews if it's the current user
        if let user = currentUser, author == user.displayName {
            userReviews.insert(newReview, at: 0)
        }

        Task {
            do {
                try await reviewService.submit(review: newReview)
            } catch {
                // Handle error - could revert optimistic update
                print("Error submitting review: \(error)")
            }
        }
    }
}

