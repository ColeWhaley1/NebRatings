//
//  NebRatingsStore.swift
//  NebRatings
//
//  Created by Cole Whaley on 11/29/25.
//

import FirebaseAuth
import FirebaseCore
import Foundation

@MainActor
@Observable
final class NebRatingsStore {
    var shows: [Show] = []
    var reviews: [Review] = [] // Made public for SwiftUI observation
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
    private let contactService: ContactService
    let authService: AuthService
    
    // Cache for searched shows to avoid re-fetching
    var showCache: [Int: Show] = [:]
    
    // Track if user has explicitly signed out to prevent auto-authentication
    private let hasExplicitlySignedOutKey = "hasExplicitlySignedOut"
    private var hasExplicitlySignedOut: Bool {
        get {
            UserDefaults.standard.bool(forKey: hasExplicitlySignedOutKey)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: hasExplicitlySignedOutKey)
        }
    }

    init(catalogService: CatalogService = TMDBService(),
         reviewService: ReviewService = FirebaseReviewService(),
         profileService: ProfileService = FirebaseProfileService(),
         listService: ListService = FirebaseListService(),
         authService: AuthService = FirebaseAuthService(),
         contactService: ContactService = FirebaseContactService())
    {
        self.catalogService = catalogService
        self.reviewService = reviewService
        self.profileService = profileService
        self.listService = listService
        self.authService = authService
        self.contactService = contactService

        // Set up auth state listener first - it will fire immediately with current state
        // This ensures we properly restore authentication from Firebase's persisted tokens
        setupAuthStateListener()
        
        // Also check synchronously as a fallback, but the listener should handle this
        // Firebase Auth persists tokens in the keychain and restores them automatically
        // IMPORTANT: Only auto-authenticate if user has NOT explicitly signed out
        Task {
            // Give Firebase a moment to restore the session if needed
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
            
            // Only restore authentication if user has NOT explicitly signed out
            // This prevents auto-authentication after explicit sign out
            if !hasExplicitlySignedOut {
                // Check if user is authenticated (Firebase should have restored session by now)
                if authService.getCurrentUserID() != nil, !isAuthenticated {
                    isAuthenticated = true
                    await loadUserProfile()
                    await loadUserLists()
                }
            } else {
                // User has explicitly signed out - ensure we're not authenticated
                // Clear any lingering Firebase Auth state
                if authService.getCurrentUserID() != nil {
                    try? await authService.signOut()
                }
                isAuthenticated = false
                currentUser = nil
                userReviews = []
                showLists = []
            }
        }
    }
    
    private func setupAuthStateListener() {
        // Listen for auth state changes to ensure we stay logged in
        // This handles token refresh and ensures persistence
        // The listener fires immediately with the current auth state when added
        guard FirebaseApp.app() != nil else {
            // If Firebase isn't ready yet, try again after a short delay
            Task {
                try? await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds
                setupAuthStateListener()
            }
            return
        }
        
        // Add state listener - this will fire immediately if there's already a user
        // Firebase Auth automatically persists tokens in the keychain and restores them
        // IMPORTANT: We check hasExplicitlySignedOut to prevent auto-authentication after sign out
        _ = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            Task { @MainActor in
                guard let self = self else { return }
                
                // If user has explicitly signed out, do NOT restore authentication
                // even if Firebase Auth has a persisted token
                if self.hasExplicitlySignedOut {
                    // Force sign out to clear any lingering tokens
                    if user != nil {
                        try? await self.authService.signOut()
                    }
                    self.isAuthenticated = false
                    self.currentUser = nil
                    self.userReviews = []
                    self.showLists = []
                    return
                }
                
                if user != nil {
                    // User is authenticated - ensure we're marked as authenticated
                    // This will fire immediately on app launch if user has persisted session
                    // Only restore authentication if there's a valid user and user hasn't signed out
                    if !self.isAuthenticated {
                        self.isAuthenticated = true
                        await self.loadUserProfile()
                        await self.loadUserLists()
                    }
                } else {
                    // User is not authenticated - this happens after sign out or if no session exists
                    // Clear all state to ensure user cannot access their account
                    self.isAuthenticated = false
                    self.currentUser = nil
                    self.userReviews = []
                    self.showLists = []
                }
            }
        }
    }
    
    func signIn(userID: String) async {
        // Clear the explicit sign out flag BEFORE setting authenticated state
        // This prevents the auth state listener from interfering with sign-in
        hasExplicitlySignedOut = false
        
        isAuthenticated = true
        await loadUserProfile()
        await loadUserLists()
    }
    
    // Method to clear the explicit sign out flag before initiating sign-in
    // This should be called before authService.signIn() to prevent the auth state listener
    // from forcing a sign out during the sign-in process
    func prepareForSignIn() {
        hasExplicitlySignedOut = false
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
                if list1.isDefault, !list2.isDefault {
                    return true
                }
                if !list1.isDefault, list2.isDefault {
                    return false
                }
                return list1.createdAt > list2.createdAt
            }
            
            showLists = fetchedLists
        } catch {
            // If error, initialize with default list locally
            if showLists.isEmpty {
                let defaultList = ShowList(name: "To Watch", isDefault: true, ownerID: userID)
                showLists = [defaultList]
            }
        }
    }
    
    func createList(name: String) async {
        guard let userID = authService.getCurrentUserID() else {
            return
        }
        
        let newList = ShowList(name: name, ownerID: userID)
        
        do {
            try await listService.createList(newList, for: userID)
            showLists.append(newList)
            
            // Sort: default list first, then by creation date (newest first)
            showLists.sort { list1, list2 in
                if list1.isDefault, !list2.isDefault {
                    return true
                }
                if !list1.isDefault, list2.isDefault {
                    return false
                }
                return list1.createdAt > list2.createdAt
            }
        } catch {
            // Error creating list
        }
    }
    
    func deleteList(_ list: ShowList) async {
        // Prevent deleting the default list
        guard !list.isDefault else {
            return
        }
        
        guard let userID = authService.getCurrentUserID() else {
            return
        }
        
        // Check if user is the owner
        guard list.ownerID == userID else {
            return
        }
        
        do {
            try await listService.deleteList(list, for: userID)
            showLists.removeAll { $0.id == list.id }
        } catch {
            // Error deleting list
        }
    }
    
    func updateListName(_ listID: String, newName: String) async {
        guard let userID = authService.getCurrentUserID() else {
            return
        }
        
        guard let listIndex = showLists.firstIndex(where: { $0.id == listID }) else {
            return
        }
        
        let trimmedName = newName.trimmingCharacters(in: .whitespaces)
        guard !trimmedName.isEmpty else {
            return
        }
        
        var updatedList = showLists[listIndex]
        
        // Check permissions - only owner can rename
        guard updatedList.ownerID == userID else {
            return
        }
        
        // Update local state immediately for optimistic UI
        updatedList.name = trimmedName
        showLists[listIndex] = updatedList
        
        // Update in Firestore
        do {
            try await listService.updateList(updatedList, for: userID)
        } catch {
            // Revert optimistic update
            if let originalList = showLists.first(where: { $0.id == listID }) {
                var revertedList = originalList
                // Find the original name from the error or reload
                // For now, just reload lists to get the correct state
                await loadUserLists()
            }
        }
    }
    
    func addShowToList(_ showID: Int, listID: String) async {
        guard let userID = authService.getCurrentUserID() else {
            return
        }
        
        guard let listIndex = showLists.firstIndex(where: { $0.id == listID }) else {
            return
        }
        
        var updatedList = showLists[listIndex]
        
        // Check permissions
        guard updatedList.canEdit(userID: userID) else {
            return
        }
        
        // Check if show is already in the list
        guard !updatedList.showIDs.contains(showID) else {
            return
        }
        
        // Add show to list
        updatedList.showIDs.append(showID)
        showLists[listIndex] = updatedList
        
        // Update in Firebase
        do {
            try await listService.updateList(updatedList, for: userID)
        } catch {
            // Revert on error
            updatedList.showIDs.removeAll { $0 == showID }
            showLists[listIndex] = updatedList
        }
    }
    
    func removeShowFromList(_ showID: Int, listID: String) async {
        guard let userID = authService.getCurrentUserID() else {
            return
        }
        
        guard let listIndex = showLists.firstIndex(where: { $0.id == listID }) else {
            return
        }
        
        var updatedList = showLists[listIndex]
        
        // Check permissions
        guard updatedList.canEdit(userID: userID) else {
            return
        }
        
        // Remove show from list
        updatedList.showIDs.removeAll { $0 == showID }
        showLists[listIndex] = updatedList
        
        // Update in Firebase
        do {
            try await listService.updateList(updatedList, for: userID)
        } catch {
            // Revert on error
            updatedList.showIDs.append(showID)
            showLists[listIndex] = updatedList
        }
    }
    
    func addContributor(_ contributorID: String, to listID: String) async {
        guard let userID = authService.getCurrentUserID() else {
            return
        }
        
        guard let listIndex = showLists.firstIndex(where: { $0.id == listID }) else {
            return
        }
        
        var updatedList = showLists[listIndex]
        
        // Only owner can add contributors
        guard updatedList.ownerID == userID else {
            return
        }
        
        // Don't add owner as contributor
        guard contributorID != updatedList.ownerID else {
            return
        }
        
        // Don't add if already a contributor
        guard !updatedList.contributorIDs.contains(contributorID) else {
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
            // Revert on error
            updatedList.contributorIDs.removeAll { $0 == contributorID }
            showLists[listIndex] = updatedList
        }
    }
    
    func removeContributor(_ contributorID: String, from listID: String) async {
        guard let userID = authService.getCurrentUserID() else {
            return
        }
        
        guard let listIndex = showLists.firstIndex(where: { $0.id == listID }) else {
            return
        }
        
        var updatedList = showLists[listIndex]
        
        // Only owner can remove contributors
        guard updatedList.ownerID == userID else {
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
            // Revert on error
            updatedList.contributorIDs.append(contributorID)
            showLists[listIndex] = updatedList
        }
    }
    
    func removeSelfAsContributor(from listID: String) async {
        guard let userID = authService.getCurrentUserID() else {
            return
        }
        
        guard let listIndex = showLists.firstIndex(where: { $0.id == listID }) else {
            return
        }
        
        var updatedList = showLists[listIndex]
        
        // Check if user is actually a contributor
        guard updatedList.contributorIDs.contains(userID) else {
            return
        }
        
        // Remove self as contributor locally
        updatedList.contributorIDs.removeAll { $0 == userID }
        showLists[listIndex] = updatedList
        
        // Update in Firebase (use ownerID for the service call, but the service will handle the removal)
        do {
            try await listService.removeContributor(userID, from: listID, for: updatedList.ownerID)
            // Reload lists to ensure consistency
            await loadUserLists()
        } catch {
            // Revert optimistic update
            updatedList.contributorIDs.append(userID)
            showLists[listIndex] = updatedList
        }
    }
    
    func searchUsers(byName name: String) async -> [UserProfile] {
        do {
            return try await profileService.searchUsers(byName: name)
        } catch {
            return []
        }
    }
    
    func fetchProfile(userID: String) async -> UserProfile? {
        do {
            return try await profileService.fetchProfile(userID: userID)
        } catch {
            return nil
        }
    }
    
    func createProfileIfNeeded(userID: String, name: String) async throws {
        // Always try to create the profile - Firestore setData will overwrite if it exists
        // This is simpler and ensures the profile is created with the correct name
        do {
            try await profileService.createProfile(userID: userID, name: name)
        } catch {
            // Re-throw the error so the caller can handle it
            throw error
        }
    }
    
    func signOut() async {
        do {
            // Mark that user has explicitly signed out - this prevents auto-authentication
            hasExplicitlySignedOut = true
            
            // Sign out from Firebase Auth - this invalidates the token and clears the keychain
            try await authService.signOut()
            
            // Clear local state immediately
            isAuthenticated = false
            currentUser = nil
            userReviews = []
            showLists = []
            
            // Verify that sign out was successful - user should be nil
            // This ensures the token is truly invalidated
            if authService.getCurrentUserID() != nil {
                // If user still exists, force clear by signing out again
                try? await authService.signOut()
            }
        } catch {
            // Even if sign out fails, mark as signed out and clear local state
            hasExplicitlySignedOut = true
            isAuthenticated = false
            currentUser = nil
            userReviews = []
            showLists = []
        }
    }
    
    func deleteAccount() async throws {
        guard let userID = authService.getCurrentUserID() else {
            throw NSError(domain: "NebRatingsStore", code: -1, userInfo: [NSLocalizedDescriptionKey: "No authenticated user"])
        }
        
        // Store username before clearing state
        let username = currentUser?.username
        
        // Delete all reviews by this user
        try await reviewService.deleteAllReviewsByUser(userID: userID)
        
        // Remove user from all lists where they are a contributor
        try await listService.removeUserFromAllLists(contributorID: userID)
        
        // Delete all lists owned by this user
        try await listService.deleteAllListsByOwner(ownerID: userID)
        
        // Delete user profile
        try await profileService.deleteProfile(userID: userID)
        
        // Delete Firebase Auth account (this must be last)
        try await authService.deleteAccount()
        
        // Clear local state
        isAuthenticated = false
        currentUser = nil
        userReviews = []
        showLists = []
        
        // Remove reviews from local cache if username was available
        if let username = username {
            reviews.removeAll { $0.author == username }
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
            // Show empty results on error rather than crashing
            shows = []
        }
    }
    
    func queryReviews(searchText: String? = nil,
                      category: Show.Category? = nil,
                      minimumRating: Double? = nil,
                      showID: Int? = nil) async
    {
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
        }
    }

    func loadUserProfile() async {
        do {
            let profile = try await profileService.fetchCurrentUser()
            currentUser = profile
            await loadUserReviews(for: profile.id)
        } catch {
            // Keep currentUser as nil if profile can't be loaded
            currentUser = nil
        }
    }
    
    func updateProfileName(_ newName: String) async throws {
        guard let userID = authService.getCurrentUserID(),
              !newName.trimmingCharacters(in: .whitespaces).isEmpty
        else {
            throw NSError(domain: "NebRatingsStore", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid user ID or empty name"])
        }
        
        try await profileService.updateProfile(userID: userID, name: newName.trimmingCharacters(in: .whitespaces))
        // Reload profile to get updated data
        await loadUserProfile()
    }

    private func loadUserReviews(for userID: String) async {
        do {
            let reviews = try await profileService.fetchReviews(for: userID)
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
            // Error fetching show details
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
            // Error fetching show details by TMDB ID
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
            // Show empty results on error rather than crashing
            recommendations = []
        }
    }
    
    func addReview(author: String, comment: String, rating: Double, to show: Show, season: Int? = nil) {
        // Use the show's ID directly - it's now the TMDB ID
        let showID = show.id
        
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
                    await updateReview(existingReview, comment: comment, rating: rating, season: season)
                    return
                }
                
                // Check Firestore if user is logged in
                if let userID = currentUser?.id {
                    let existingReviewQuery = ReviewQuery(
                        showID: showID,
                        authorID: userID,
                        limit: 100 // Get all reviews to filter by season client-side
                    )
                    let existingReviews = try await reviewService.queryReviews(existingReviewQuery)
                    
                    // Filter by matching season (both nil means "entire show")
                    if let existingReview = existingReviews.first(where: { $0.season == season }) {
                        // User already has a review for this season - update it
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
            // Error updating review
        }
    }
    
    func updateReview(_ review: Review, comment: String, rating: Double) {
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
    
    func submitContactForm(_ form: ContactForm) async throws {
        try await contactService.submitContactForm(form)
    }
}
