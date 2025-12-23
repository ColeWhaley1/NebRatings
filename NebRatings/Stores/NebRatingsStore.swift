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
    var showLists: [ShowList] = []
    
    var isSearchingShows = false
    private(set) var isQueryingReviews = false
    private(set) var isLoadingRecommendations = false

    private let catalogService: CatalogService
    private let reviewService: ReviewService
    private let profileService: ProfileService
    private let listService: ListService
    let authService: AuthService
    
    // Cache for searched shows to avoid re-fetching
    var showCache: [Int: Show] = [:]

    init(catalogService: CatalogService = TMDBService(),
         reviewService: ReviewService = FirebaseReviewService(),
         profileService: ProfileService = FirebaseProfileService(),
         listService: ListService = FirebaseListService(),
         authService: AuthService = FirebaseAuthService()) {
        self.catalogService = catalogService
        self.reviewService = reviewService
        self.profileService = profileService
        self.listService = listService
        self.authService = authService

        // Check if user is already authenticated
        if let userID = authService.getCurrentUserID() {
            isAuthenticated = true
            Task {
                await loadUserProfile()
                await loadUserLists()
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
                try await createProfileIfNeeded(userID: userID, name: "Cole")
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
        await loadUserLists()
    }
    
    func loadUserLists() async {
        guard let userID = authService.getCurrentUserID() else {
            showLists = []
            return
        }
        
        do {
            var fetchedLists = try await listService.fetchLists(for: userID)
            
            // If no lists exist, create default "To Watch" list
            if fetchedLists.isEmpty {
                let defaultList = ShowList(name: "To Watch", isDefault: true, ownerID: userID)
                try await listService.createList(defaultList, for: userID)
                fetchedLists = [defaultList]
            } else {
                // Ensure default list exists
                let hasDefault = fetchedLists.contains { $0.isDefault }
                if !hasDefault {
                    let defaultList = ShowList(name: "To Watch", isDefault: true, ownerID: userID)
                    try await listService.createList(defaultList, for: userID)
                    fetchedLists.insert(defaultList, at: 0)
                }
            }
            
            // Sort: default list first, then by creation date (newest first)
            fetchedLists.sort { list1, list2 in
                if list1.isDefault && !list2.isDefault {
                    return true
                }
                if !list1.isDefault && list2.isDefault {
                    return false
                }
                return list1.createdAt > list2.createdAt
            }
            
            showLists = fetchedLists
        } catch {
            print("❌ Error loading lists: \(error.localizedDescription)")
            // If error, initialize with default list locally
            if showLists.isEmpty {
                let defaultList = ShowList(name: "To Watch", isDefault: true, ownerID: userID)
                showLists = [defaultList]
            }
        }
    }
    
    func createList(name: String) async {
        guard let userID = authService.getCurrentUserID() else {
            print("⚠️ Cannot create list: no authenticated user")
            return
        }
        
        print("📝 Creating list '\(name)' for user: \(userID)")
        let newList = ShowList(name: name, ownerID: userID)
        print("📝 Created ShowList with id: \(newList.id), ownerID: \(newList.ownerID)")
        
        do {
            try await listService.createList(newList, for: userID)
            print("✅ List created successfully in Firebase")
            showLists.append(newList)
            print("✅ List added to local showLists array (count: \(showLists.count))")
            
            // Sort: default list first, then by creation date (newest first)
            showLists.sort { list1, list2 in
                if list1.isDefault && !list2.isDefault {
                    return true
                }
                if !list1.isDefault && list2.isDefault {
                    return false
                }
                return list1.createdAt > list2.createdAt
            }
            print("✅ Lists sorted (count: \(showLists.count))")
        } catch {
            print("❌ Error creating list: \(error.localizedDescription)")
            print("❌ Error details: \(error)")
        }
    }
    
    func deleteList(_ list: ShowList) async {
        // Prevent deleting the default list
        guard !list.isDefault else {
            print("⚠️ Cannot delete default list")
            return
        }
        
        guard let userID = authService.getCurrentUserID() else {
            print("⚠️ Cannot delete list: no authenticated user")
            return
        }
        
        do {
            try await listService.deleteList(list, for: userID)
            showLists.removeAll { $0.id == list.id }
        } catch {
            print("❌ Error deleting list: \(error.localizedDescription)")
        }
    }
    
    func addShowToList(_ showID: Int, listID: String) async {
        guard let userID = authService.getCurrentUserID() else {
            print("⚠️ Cannot add show to list: no authenticated user")
            return
        }
        
        guard let listIndex = showLists.firstIndex(where: { $0.id == listID }) else {
            print("⚠️ List not found: \(listID)")
            return
        }
        
        var updatedList = showLists[listIndex]
        
        // Check permissions
        guard updatedList.canEdit(userID: userID) else {
            print("⚠️ User does not have permission to edit this list")
            return
        }
        
        // Check if show is already in the list
        guard !updatedList.showIDs.contains(showID) else {
            print("⚠️ Show already in list")
            return
        }
        
        // Add show to list
        updatedList.showIDs.append(showID)
        showLists[listIndex] = updatedList
        
        // Update in Firebase
        do {
            try await listService.updateList(updatedList, for: userID)
        } catch {
            print("❌ Error updating list: \(error.localizedDescription)")
            // Revert on error
            updatedList.showIDs.removeAll { $0 == showID }
            showLists[listIndex] = updatedList
        }
    }
    
    func removeShowFromList(_ showID: Int, listID: String) async {
        guard let userID = authService.getCurrentUserID() else {
            print("⚠️ Cannot remove show from list: no authenticated user")
            return
        }
        
        guard let listIndex = showLists.firstIndex(where: { $0.id == listID }) else {
            print("⚠️ List not found: \(listID)")
            return
        }
        
        var updatedList = showLists[listIndex]
        
        // Check permissions
        guard updatedList.canEdit(userID: userID) else {
            print("⚠️ User does not have permission to edit this list")
            return
        }
        
        // Remove show from list
        updatedList.showIDs.removeAll { $0 == showID }
        showLists[listIndex] = updatedList
        
        // Update in Firebase
        do {
            try await listService.updateList(updatedList, for: userID)
        } catch {
            print("❌ Error updating list: \(error.localizedDescription)")
            // Revert on error
            updatedList.showIDs.append(showID)
            showLists[listIndex] = updatedList
        }
    }
    
    func addContributor(_ contributorID: String, to listID: String) async {
        guard let userID = authService.getCurrentUserID() else {
            print("⚠️ Cannot add contributor: no authenticated user")
            return
        }
        
        guard let listIndex = showLists.firstIndex(where: { $0.id == listID }) else {
            print("⚠️ List not found: \(listID)")
            return
        }
        
        var updatedList = showLists[listIndex]
        
        // Only owner can add contributors
        guard updatedList.ownerID == userID else {
            print("⚠️ Only the list owner can add contributors")
            return
        }
        
        // Don't add owner as contributor
        guard contributorID != updatedList.ownerID else {
            print("⚠️ Cannot add list owner as contributor")
            return
        }
        
        // Don't add if already a contributor
        guard !updatedList.contributorIDs.contains(contributorID) else {
            print("⚠️ User is already a contributor")
            return
        }
        
        // Add contributor locally
        updatedList.contributorIDs.append(contributorID)
        showLists[listIndex] = updatedList
        
        // Update in Firebase
        do {
            try await listService.addContributor(contributorID, to: listID, for: userID)
            // Reload lists to ensure consistency
            await loadUserLists()
        } catch {
            print("❌ Error adding contributor: \(error.localizedDescription)")
            // Revert on error
            updatedList.contributorIDs.removeAll { $0 == contributorID }
            showLists[listIndex] = updatedList
        }
    }
    
    func removeContributor(_ contributorID: String, from listID: String) async {
        guard let userID = authService.getCurrentUserID() else {
            print("⚠️ Cannot remove contributor: no authenticated user")
            return
        }
        
        guard let listIndex = showLists.firstIndex(where: { $0.id == listID }) else {
            print("⚠️ List not found: \(listID)")
            return
        }
        
        var updatedList = showLists[listIndex]
        
        // Only owner can remove contributors
        guard updatedList.ownerID == userID else {
            print("⚠️ Only the list owner can remove contributors")
            return
        }
        
        // Remove contributor locally
        updatedList.contributorIDs.removeAll { $0 == contributorID }
        showLists[listIndex] = updatedList
        
        // Update in Firebase
        do {
            try await listService.removeContributor(contributorID, from: listID, for: userID)
            // Reload lists to ensure consistency
            await loadUserLists()
        } catch {
            print("❌ Error removing contributor: \(error.localizedDescription)")
            // Revert on error
            updatedList.contributorIDs.append(contributorID)
            showLists[listIndex] = updatedList
        }
    }
    
    func searchUsers(byName name: String) async -> [UserProfile] {
        do {
            return try await profileService.searchUsers(byName: name)
        } catch {
            print("❌ Error searching users: \(error.localizedDescription)")
            return []
        }
    }
    
    func fetchProfile(userID: String) async -> UserProfile? {
        do {
            return try await profileService.fetchProfile(userID: userID)
        } catch {
            print("❌ Error fetching profile: \(error.localizedDescription)")
            return nil
        }
    }
    
    func createProfileIfNeeded(userID: String, name: String) async throws {
        // Always try to create the profile - Firestore setData will overwrite if it exists
        // This is simpler and ensures the profile is created with the correct name
        do {
            print("📝 Creating profile for user: \(userID) with name: \(name)")
            try await profileService.createProfile(userID: userID, name: name)
            print("✅ Profile created/updated successfully for user: \(userID)")
        } catch {
            print("❌ Error creating profile: \(error.localizedDescription)")
            // Re-throw the error so the caller can handle it
            throw error
        }
    }
    
    func signOut() async {
        do {
            try await authService.signOut()
            isAuthenticated = false
            currentUser = nil
            userReviews = []
            showLists = []
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
        
        // For show-specific queries, use a higher limit to fetch all reviews
        // For feed queries, use a smaller limit
        let limit = showID != nil ? 1000 : 100
        
        let query = ReviewQuery(
            searchText: searchText,
            category: category,
            minimumRating: minimumRating,
            showID: showID,
            limit: limit
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
    
    func updateProfileName(_ newName: String) async throws {
        guard let userID = authService.getCurrentUserID(),
              !newName.trimmingCharacters(in: .whitespaces).isEmpty else {
            throw NSError(domain: "NebRatingsStore", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid user ID or empty name"])
        }
        
        try await profileService.updateProfile(userID: userID, name: newName.trimmingCharacters(in: .whitespaces))
        // Reload profile to get updated data
        await loadUserProfile()
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
    
    func addReview(author: String, comment: String, rating: Double, to show: Show, season: Int? = nil) {
        // Use the show's ID directly - it's now the TMDB ID
        let showID = show.id
        print("📝 Posting review with showID: \(showID), season: \(season?.description ?? "nil")")
        
        // Safety check: if user already has a review for the same season (or both nil), update it instead of creating duplicate
        // (This shouldn't happen if UI is working correctly, but serves as a safeguard)
        Task {
            do {
                // Check local state first - only match if season is also the same
                let localExistingReview = reviews.first { review in
                    review.showID == showID && review.author == author && review.season == season
                }
                
                if let existingReview = localExistingReview {
                    // User already has a review for this show/season - update it
                    print("📝 User already has a review for this show/season, updating existing review")
                    await updateReview(existingReview, comment: comment, rating: rating, season: season)
                    return
                }
                
                // Check Firestore if user is logged in
                if let userID = currentUser?.id {
                    let existingReviewQuery = ReviewQuery(
                        showID: showID,
                        authorID: userID,
                        limit: 100  // Get all reviews to filter by season client-side
                    )
                    let existingReviews = try await reviewService.queryReviews(existingReviewQuery)
                    
                    // Filter by matching season (both nil means "entire show")
                    if let existingReview = existingReviews.first(where: { $0.season == season }) {
                        // User already has a review for this season - update it
                        print("📝 User already has a review in Firestore for this season, updating existing review")
                        await updateReview(existingReview, comment: comment, rating: rating, season: season)
                        return
                    }
                }
                
                // No existing review - create a new one
                let newReview = Review(showID: showID, showTitle: show.title, showCategory: show.category, author: author, comment: comment, nebRating: rating, season: season)
                
                // Add to local state immediately for optimistic UI
                if !reviews.contains(where: { $0.id == newReview.id }) {
                    var updatedReviews = reviews
                    updatedReviews.insert(newReview, at: 0)
                    reviews = updatedReviews
                }
                
                // Update user reviews if it's the current user
                if let user = currentUser, author == user.username {
                    if !userReviews.contains(where: { $0.id == newReview.id }) {
                        var updatedUserReviews = userReviews
                        updatedUserReviews.insert(newReview, at: 0)
                        userReviews = updatedUserReviews
                    }
                }
                
                // Submit to Firestore
                try await reviewService.submit(review: newReview)
                // Refresh reviews for this show
                await queryReviews(showID: show.id)
            } catch {
                // Handle error
                print("Error submitting review: \(error)")
            }
        }
    }
    
    private func updateReview(_ review: Review, comment: String, rating: Double, season: Int? = nil) async {
        let updatedReview = Review(
            id: review.id,
            showID: review.showID,
            showTitle: review.showTitle,
            showCategory: review.showCategory,
            author: review.author,
            comment: comment,
            nebRating: rating,
            timestamp: review.timestamp, // Keep original timestamp
            season: season ?? review.season // Use provided season or keep existing
        )
        
        // Update in local state immediately for optimistic UI
        if let index = reviews.firstIndex(where: { $0.id == review.id }) {
            var updatedReviews = reviews
            updatedReviews[index] = updatedReview
            reviews = updatedReviews
        }
        
        // Update user reviews if it's the current user
        if let user = currentUser, review.author == user.username {
            if let index = userReviews.firstIndex(where: { $0.id == review.id }) {
                var updatedUserReviews = userReviews
                updatedUserReviews[index] = updatedReview
                userReviews = updatedUserReviews
            }
        }
        
        // Update in Firestore
        do {
            try await reviewService.update(review: updatedReview)
            // Refresh reviews for this show
            await queryReviews(showID: review.showID)
        } catch {
            print("Error updating review: \(error)")
        }
    }
    
    func updateReview(_ review: Review, comment: String, rating: Double) {
        print("📝 Updating review with ID: \(review.id)")
        
        // Create updated review with new comment and rating, keeping season from original
        let updatedReview = Review(
            id: review.id,
            showID: review.showID,
            showTitle: review.showTitle,
            showCategory: review.showCategory,
            author: review.author,
            comment: comment.trimmingCharacters(in: .whitespacesAndNewlines),
            nebRating: rating,
            timestamp: review.timestamp, // Keep original timestamp
            season: review.season // Keep original season
        )
        
        // Update in local state immediately for optimistic UI
        if let index = reviews.firstIndex(where: { $0.id == review.id }) {
            var updatedReviews = reviews
            updatedReviews[index] = updatedReview
            reviews = updatedReviews
        }
        
        // Update user reviews if it's the current user
        if let user = currentUser, review.author == user.username {
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
                if let user = currentUser, review.author == user.username {
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
        if let user = currentUser, review.author == user.username {
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
                
                if let user = currentUser, review.author == user.username {
                    var updatedUserReviews = userReviews
                    updatedUserReviews.append(review)
                    userReviews = updatedUserReviews.sorted { $0.timestamp > $1.timestamp }
                }
            }
        }
    }
}

