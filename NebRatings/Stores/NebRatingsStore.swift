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
    var reviews: [Review] = []  // Made public for SwiftUI observation
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
    private var showCache: [Int: Show] = [:]

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
        } else {
            // Development-only auto-sign-in
            #if DEBUG
            Task {
                await autoSignInForDevelopment()
            }
            #endif
        }
    }
    
    #if DEBUG
    /// Development-only auto-sign-in for easier testing
    private func autoSignInForDevelopment() async {
        // Only auto-sign-in if not already authenticated
        guard !isAuthenticated, authService.getCurrentUserID() == nil else {
            return
        }
        
        let devEmail = "colewhaley1@gmail.com"
        let devPassword = "nebratings"
        
        do {
            // Try to sign in with development credentials
            let userID = try await authService.signIn(email: devEmail, password: devPassword)
            await signIn(userID: userID)
            print("✅ Development auto-sign-in successful")
        } catch {
            // If sign-in fails, try to create the account
            do {
                let userID = try await authService.signUp(email: devEmail, password: devPassword)
                await createProfileIfNeeded(userID: userID, name: "Cole")
                await signIn(userID: userID)
                print("✅ Development account created and signed in")
            } catch {
                print("⚠️ Development auto-sign-in failed: \(error.localizedDescription)")
            }
        }
    }
    #endif
    
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
                    showID: Int? = nil) async {
        isQueryingReviews = true
        defer { isQueryingReviews = false }
        
        let query = ReviewQuery(
            searchText: searchText,
            category: category,
            minimumRating: minimumRating,
            showID: showID,
            limit: 100
        )
        
        print("Query:", query)
        
        do {
            let results = try await reviewService.queryReviews(query)
            
            if let showID = showID {
                // When querying for a specific show, merge results to preserve optimistic updates
                // Use a dictionary to efficiently merge and update reviews
                var reviewsDict: [UUID: Review] = [:]
                
                // First, add all existing reviews (preserves local optimistic updates)
                for review in reviews {
                    reviewsDict[review.id] = review
                }
                
                // Then, update/add reviews from Firestore (Firestore data takes precedence for existing reviews)
                for result in results {
                    reviewsDict[result.id] = result
                }
                
                // Convert back to array, sorted by timestamp (newest first)
                let sortedReviews = Array(reviewsDict.values).sorted { $0.timestamp > $1.timestamp }
                reviews = sortedReviews
            } else {
                // When querying the feed (no showID), replace reviews with filtered results only
                // This ensures the UI shows only the filtered reviews
                let sortedReviews = results.sorted { $0.timestamp > $1.timestamp }
                reviews = sortedReviews
            }
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
    
    func fetchShowDetails(id: Int, category: Show.Category) async -> Show? {
        // Check cache first
        if let cached = showCache[id] {
            return cached
        }
        
        // Fetch from API
        do {
            if let show = try await catalogService.fetchShowDetails(id: String(id), category: category) {
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
        // Filter reviews for the specific show
        // This method is called from views, so it will trigger updates when reviews array changes
        return reviews.filter { $0.showID == show.id }
    }

    func show(for review: Review) -> Show? {
        // Check cache first
        if let cached = showCache[review.showID] {
            return cached
        }
        
        // Check current shows list
        if let found = shows.first(where: { $0.id == review.showID }) {
            return found
        }
        
        // review.showID is now the TMDB ID, so fetch the show from TMDB
        // Create a minimal show for immediate navigation, then fetch details
        let minimalShow = Show(
            id: review.showID,
            title: review.showTitle,
            category: review.showCategory,
            year: 0,
            synopsis: "",
            tagline: "",
            streamingService: "",
            reviews: []
        )
        
        // Fetch full details in background and cache it
        Task {
            if let fullShow = await fetchShowDetailsByTMDBID(tmdbID: review.showID, category: review.showCategory) {
                showCache[review.showID] = fullShow
            }
        }
        
        return minimalShow
    }

    func loadRecommendations(for show: Show) async {
        // show.id is now the TMDB ID
        let tmdbID = show.id
        
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
        // Use the show's ID directly - it's now the TMDB ID
        let showID = show.id
        print("📝 Posting review with showID: \(showID)")
        
        let newReview = Review(showID: showID, showTitle: show.title, showCategory: show.category, author: author, comment: comment, nebRating: rating)
        
        // Add to local state immediately for optimistic UI
        // This ensures the review appears in the UI right away
        // Create a new array to trigger SwiftUI updates
        if !reviews.contains(where: { $0.id == newReview.id }) {
            var updatedReviews = reviews
            updatedReviews.insert(newReview, at: 0)
            reviews = updatedReviews
        }
        
        // Update user reviews if it's the current user
        if let user = currentUser, author == user.name {
            if !userReviews.contains(where: { $0.id == newReview.id }) {
                var updatedUserReviews = userReviews
                updatedUserReviews.insert(newReview, at: 0)
                userReviews = updatedUserReviews
            }
        }

        // Submit to Firestore in background
        Task {
            do {
                try await reviewService.submit(review: newReview)
                // Refresh reviews for this show to ensure consistency with Firestore
                // This will merge the Firestore version with local reviews
                await queryReviews(showID: show.id)
            } catch {
                // Handle error - revert optimistic update
                print("Error submitting review: \(error)")
                // Remove the optimistic update on error - create new array to trigger SwiftUI updates
                reviews = reviews.filter { $0.id != newReview.id }
                if let user = currentUser, author == user.name {
                    userReviews = userReviews.filter { $0.id != newReview.id }
                }
            }
        }
    }
    
    func updateReview(_ review: Review, comment: String, rating: Double) {
        print("📝 Updating review with ID: \(review.id)")
        
        // Create updated review with new comment and rating
        let updatedReview = Review(
            id: review.id,
            showID: review.showID,
            showTitle: review.showTitle,
            showCategory: review.showCategory,
            author: review.author,
            comment: comment.trimmingCharacters(in: .whitespacesAndNewlines),
            nebRating: rating,
            timestamp: review.timestamp // Keep original timestamp
        )
        
        // Update in local state immediately for optimistic UI
        if let index = reviews.firstIndex(where: { $0.id == review.id }) {
            var updatedReviews = reviews
            updatedReviews[index] = updatedReview
            reviews = updatedReviews
        }
        
        // Update user reviews if it's the current user
        if let user = currentUser, review.author == user.name {
            if let index = userReviews.firstIndex(where: { $0.id == review.id }) {
                var updatedUserReviews = userReviews
                updatedUserReviews[index] = updatedReview
                userReviews = updatedUserReviews
            }
        }
        
        // Update in Firestore in background
        Task {
            do {
                try await reviewService.update(review: updatedReview)
                // Refresh reviews to ensure consistency with Firestore
                await queryReviews(showID: review.showID)
            } catch {
                // Handle error - revert optimistic update
                print("Error updating review: \(error)")
                // Revert to original review
                if let index = reviews.firstIndex(where: { $0.id == review.id }) {
                    var updatedReviews = reviews
                    updatedReviews[index] = review
                    reviews = updatedReviews
                }
                if let user = currentUser, review.author == user.name {
                    if let index = userReviews.firstIndex(where: { $0.id == review.id }) {
                        var updatedUserReviews = userReviews
                        updatedUserReviews[index] = review
                        userReviews = updatedUserReviews
                    }
                }
            }
        }
    }
    
    func deleteReview(_ review: Review) {
        print("🗑️ Deleting review with ID: \(review.id)")
        
        // Remove from local state immediately for optimistic UI
        reviews = reviews.filter { $0.id != review.id }
        
        // Remove from user reviews if it's the current user
        if let user = currentUser, review.author == user.name {
            userReviews = userReviews.filter { $0.id != review.id }
        }
        
        // Delete from Firestore in background
        Task {
            do {
                try await reviewService.delete(review: review)
                // Refresh reviews to ensure consistency with Firestore
                await queryReviews(showID: review.showID)
            } catch {
                // Handle error - restore optimistic update
                print("Error deleting review: \(error)")
                // Restore the review
                var updatedReviews = reviews
                updatedReviews.append(review)
                reviews = updatedReviews.sorted { $0.timestamp > $1.timestamp }
                
                if let user = currentUser, review.author == user.name {
                    var updatedUserReviews = userReviews
                    updatedUserReviews.append(review)
                    userReviews = updatedUserReviews.sorted { $0.timestamp > $1.timestamp }
                }
            }
        }
    }
}

