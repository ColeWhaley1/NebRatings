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
    var shows: [Show] = []
    private(set) var reviews: [Review] = []
    private(set) var currentUser: UserProfile?
    private(set) var userReviews: [Review] = []
    private(set) var isAuthenticated = false
    private(set) var recommendations: [Show] = []
    
    var isSearchingShows = false
    private(set) var isQueryingReviews = false
    private(set) var isLoadingRecommendations = false

    private let catalogService: CatalogService
    private let reviewService: ReviewService
    private let profileService: ProfileService
    let authService: AuthService
    
    // Cache for searched shows to avoid re-fetching
    private var showCache: [UUID: Show] = [:]

    init(catalogService: CatalogService = TMDBService(),
         reviewService: ReviewService = FirebaseReviewService(),
         profileService: ProfileService = FirebaseProfileService(),
         authService: AuthService = FirebaseAuthService()) {
        self.catalogService = catalogService
        self.reviewService = reviewService
        self.profileService = profileService
        self.authService = authService

        // Check if user is already authenticated
        if let userID = authService.getCurrentUserID() {
            isAuthenticated = true
            Task {
                await loadUserProfile()
            }
        }
    }
    
    func signIn(userID: String) async {
        isAuthenticated = true
        await loadUserProfile()
    }
    
    func createProfileIfNeeded(userID: String, name: String) async {
        do {
            try await profileService.createProfile(userID: userID, name: name)
        } catch {
            // If profile already exists, that's okay - just continue
            print("Profile creation note: \(error.localizedDescription)")
        }
    }
    
    func signOut() async {
        do {
            try await authService.signOut()
            isAuthenticated = false
            currentUser = nil
            userReviews = []
        } catch {
            print("Error signing out: \(error)")
        }
    }

    func searchShows(query: String, category: Show.Category? = nil) async {
        guard !query.isEmpty else {
            shows = []
            return
        }
        
        isSearchingShows = true
        defer { isSearchingShows = false }
        
        do {
            let results = try await catalogService.searchShows(query: query, category: category)
            shows = results
            
            // Update cache
            for show in results {
                showCache[show.id] = show
            }
        } catch {
            // Handle error - could show error state
            print("Error searching shows: \(error)")
            // Show empty results on error rather than crashing
            shows = []
        }
    }
    
    func loadTrendingShows(category: Show.Category? = nil) async {
        isSearchingShows = true
        defer { isSearchingShows = false }
        
        do {
            let results = try await catalogService.fetchTrendingShows(category: category)
            shows = results
            
            // Update cache
            for show in results {
                showCache[show.id] = show
            }
        } catch {
            // Handle error - could show error state
            print("Error loading trending shows: \(error)")
            // Show empty results on error rather than crashing
            shows = []
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
            print(profile)
            currentUser = profile
            await loadUserReviews(for: profile.id)
        } catch {
            // Log error for debugging
            print("Error loading user profile: \(error.localizedDescription)")
            // Keep currentUser as nil if profile can't be loaded
            currentUser = nil
        }
    }

    private func loadUserReviews(for userID: String) async {
        do {
            let reviews = try await profileService.fetchReviews(for: userID)
            print(reviews)
            userReviews = reviews
        } catch {
            // Keep existing user reviews.
        }
    }
    
    func fetchShowDetails(id: UUID, category: Show.Category) async -> Show? {
        // Check cache first
        if let cached = showCache[id] {
            return cached
        }
        
        // Fetch from API
        do {
            if let show = try await catalogService.fetchShowDetails(id: id.uuidString, category: category) {
                showCache[id] = show
                return show
            }
        } catch {
            print("Error fetching show details: \(error)")
        }
        
        return nil
    }
    
    func fetchShowDetailsByTMDBID(tmdbID: Int, category: Show.Category) async -> Show? {
        // Fetch from API using TMDB ID
        do {
            if let show = try await catalogService.fetchShowDetails(id: String(tmdbID), category: category) {
                // Cache by the show's UUID if it exists
                showCache[show.id] = show
                return show
            }
        } catch {
            print("Error fetching show details by TMDB ID: \(error)")
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

    func loadRecommendations(for show: Show) async {
        guard let tmdbID = show.tmdbID else {
            recommendations = []
            return
        }
        
        isLoadingRecommendations = true
        defer { isLoadingRecommendations = false }
        
        do {
            let results = try await catalogService.fetchRecommendations(tmdbID: tmdbID, category: show.category)
            recommendations = results
            
            // Update cache
            for show in results {
                showCache[show.id] = show
            }
        } catch {
            // Handle error - could show error state
            print("Error loading recommendations: \(error)")
            // Show empty results on error rather than crashing
            recommendations = []
        }
    }
    
    func addReview(author: String, comment: String, rating: Double, to show: Show) {
        let newReview = Review(showID: show.id, showTitle: show.title, author: author, comment: comment, nebRating: rating)
        
        // Add to local state immediately for optimistic UI
        reviews.insert(newReview, at: 0)
        
        // Update user reviews if it's the current user
        if let user = currentUser, author == user.name {
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

