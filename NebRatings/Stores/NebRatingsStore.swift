//
//  NebRatingsStore.swift
//  NebRatings
//
//  Created by Cole Whaley on 11/29/25.
//

import FirebaseAuth
import FirebaseCore
import Foundation
import SwiftUI

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

    /// The whole Discover browse payload, owned by the store so it can be
    /// warmed during the splash screen and is instant when the tab appears.
    var discoverFeed = DiscoverFeed()
    private var discoverLoadTask: Task<Void, Never>?

    /// Everything the Discover browse view renders. Kept here (not in the
    /// view) so loading can start at launch, before the view exists.
    struct DiscoverFeed {
        var seasonal: [SeasonalCollection] = []
        var trendingWeek: [Show] = []
        var recentlyReleased: [Show] = []
        var hiddenGems: [Show] = []
        var awardWinners: [Show] = []
        var favoriteGenreShows: [Show] = []
        var becauseYouRatedTitle: String?
        var becauseYouRatedShows: [Show] = []
        var highestRatedMonth: [RankedShow] = []
        var mostReviewedMonth: [RankedShow] = []
        var highestRatedYear: [RankedShow] = []
        var isLoaded = false
    }
    
    var isSearchingShows = false
    private(set) var isQueryingReviews = false
    private(set) var isLoadingRecommendations = false

    var relationships: [Friendship] = []
    /// Cache of other users' profiles keyed by userID — used to render author avatars on reviews.
    var profileCache: [String: UserProfile] = [:]

    /// The root tab currently selected. Lives in the store (not ContentView
    /// @State) so deep views can route — e.g. tapping your *own* username on
    /// a review switches to the Profile tab instead of pushing a duplicate
    /// profile screen onto the current stack.
    var selectedTab: AppTab = .discover

    private let catalogService: CatalogService
    private let reviewService: ReviewService
    private let profileService: ProfileService
    let listService: ListService // Made internal for ListsView migration logic
    private let contactService: ContactService
    let authService: AuthService
    private let friendshipService: FriendshipService
    private let activityService: ActivityService
    private let appConfigService: AppConfigService

    // Cache for searched shows to avoid re-fetching
    var showCache: [Int: Show] = [:]

    /// TMDB keyword name → id, resolved once per launch (seasonal queries).
    private var keywordIDCache: [String: Int] = [:]

    /// Cast lists by TMDB id — fetched the first time a title's cast screen
    /// opens, instant on revisits.
    private var castCache: [Int: [CastMember]] = [:]
    
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
         contactService: ContactService = FirebaseContactService(),
         friendshipService: FriendshipService = FirebaseFriendshipService(),
         activityService: ActivityService = FirebaseActivityService(),
         appConfigService: AppConfigService = FirebaseAppConfigService())
    {
        self.catalogService = catalogService
        self.reviewService = reviewService
        self.profileService = profileService
        self.listService = listService
        self.authService = authService
        self.contactService = contactService
        self.friendshipService = friendshipService
        self.activityService = activityService
        self.appConfigService = appConfigService

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
                    await loadRelationships()
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
                relationships = []
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
                    self.relationships = []
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
                        await self.loadRelationships()
                        // Warm Discover + the friends' reviews feed now (during
                        // the splash) so the first tabs are instant. Fire-and-
                        // forget — never blocks auth.
                        Task { await self.preloadDiscover() }
                        Task { await self.queryReviews() }
                    }
                } else {
                    // User is not authenticated - this happens after sign out or if no session exists
                    // Clear all state to ensure user cannot access their account
                    self.isAuthenticated = false
                    self.currentUser = nil
                    self.userReviews = []
                    self.showLists = []
                    self.relationships = []
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
        await loadRelationships()
        Task { await preloadDiscover() }
        Task { await queryReviews() }
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
            // No-op today (new lists start private), but future-proof: if
            // creation defaults ever change, the event records correctly.
            recordListActivity(kind: .createdList, list: newList)

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
            // Its feed events must go with it (best effort).
            Task { try? await activityService.removeListEvents(listID: list.id) }
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
            await loadUserLists()
        }
    }
    
    /// Updates autoRemoveOnReview for a list. Only available when contributorIDs.isEmpty (single-owner list).
    func updateAutoRemoveOnReview(listID: String, enabled: Bool) async {
        guard let userID = authService.getCurrentUserID() else {
            return
        }
        
        guard let listIndex = showLists.firstIndex(where: { $0.id == listID }) else {
            return
        }
        
        var updatedList = showLists[listIndex]
        
        // Only owner can change this; only single-owner lists support it
        guard updatedList.ownerID == userID else {
            return
        }
        guard updatedList.contributorIDs.isEmpty else {
            return
        }
        
        updatedList.autoRemoveOnReview = enabled
        showLists[listIndex] = updatedList
        
        do {
            try await listService.updateList(updatedList, for: userID)
        } catch {
            await loadUserLists()
        }
    }
    
    /// Updates who can see a list. Owner-only.
    func updateListVisibility(listID: String, visibility: ListVisibility) async {
        guard let userID = authService.getCurrentUserID() else {
            return
        }

        guard let listIndex = showLists.firstIndex(where: { $0.id == listID }) else {
            return
        }

        var updatedList = showLists[listIndex]

        // Only the owner decides who can see the list.
        guard updatedList.ownerID == userID else {
            return
        }

        updatedList.visibility = visibility
        showLists[listIndex] = updatedList

        do {
            try await listService.updateList(updatedList, for: userID)
            if visibility == .privateList {
                // Going private: the list's feed history must disappear.
                Task { try? await activityService.removeListEvents(listID: updatedList.id) }
            } else {
                // Now visible: (re)announce it. Idempotent doc id, and the
                // timestamp is the list's createdAt, so it lands in the feed
                // where the list's age says it should.
                recordListActivity(kind: .createdList, list: updatedList)
            }
        } catch {
            await loadUserLists()
        }
    }

    // New method that accepts Show object (includes category). seasons: nil = entire show; [1,2] = specific seasons (series only).
    func addShowToList(_ show: Show, listID: String, seasons: [Int]? = nil) async {
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
        
        // For movies, always use nil (entire show). Empty array = entire show.
        let effectiveSeasons: [Int]?
        if show.category == .series, let s = seasons, !s.isEmpty {
            effectiveSeasons = s
        } else {
            effectiveSeasons = nil
        }
        
        let reference = ShowReference(id: show.id, category: show.category, seasons: effectiveSeasons)
        
        let isNewAddition: Bool
        if let existingIndex = updatedList.showReferences.firstIndex(where: { $0.id == show.id && $0.category == show.category }) {
            // Show already in list - update seasons (merge or replace)
            updatedList.showReferences[existingIndex] = reference
            isNewAddition = false
        } else {
            updatedList.showReferences.append(reference)
            isNewAddition = true
        }
        showLists[listIndex] = updatedList

        // Update in Firebase
        do {
            try await listService.updateList(updatedList, for: userID)
            // Feed event only for genuinely new additions — season tweaks
            // and re-saves of existing entries don't re-announce.
            if isNewAddition {
                recordListActivity(kind: .addedToList, list: updatedList, show: show)
            }
        } catch {
            // Revert on error - reload lists from server
            await loadUserLists()
        }
    }
    
    // Backwards compatibility method that accepts just ID
    func addShowToList(_ showID: Int, listID: String) async {
        // Try to find the show in cache to get its category
        if let show = showCache[showID] {
            await addShowToList(show, listID: listID)
        } else {
            // If not in cache, create a reference with default category (will be corrected when loaded)
            // This maintains backwards compatibility
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
            guard !updatedList.showReferences.contains(where: { $0.id == showID }) else {
                return
            }
            
            // Add with default category (will be corrected when show is loaded)
            let reference = ShowReference(id: showID, category: .movie)
            updatedList.showReferences.append(reference)
            showLists[listIndex] = updatedList
            
            // Update in Firebase
            do {
                try await listService.updateList(updatedList, for: userID)
            } catch {
                // Revert on error
                updatedList.showReferences.removeAll { $0.id == showID }
                showLists[listIndex] = updatedList
            }
        }
    }
    
    // New method that accepts Show object (includes category)
    func removeShowFromList(_ show: Show, listID: String) async {
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
        updatedList.showReferences.removeAll { $0.id == show.id && $0.category == show.category }
        showLists[listIndex] = updatedList
        
        // Update in Firebase
        do {
            try await listService.updateList(updatedList, for: userID)
        } catch {
            // Revert on error
            let reference = ShowReference(id: show.id, category: show.category)
            updatedList.showReferences.append(reference)
            showLists[listIndex] = updatedList
        }
    }
    
    /// Removes show from lists that have autoRemoveOnReview enabled. Only applies to single-owner lists (contributorIDs.isEmpty).
    private func performAutoRemoveFromLists(showID: Int, showCategory: Show.Category) async {
        guard let userID = authService.getCurrentUserID() else {
            return
        }
        
        for list in showLists where list.contributorIDs.isEmpty
            && list.autoRemoveOnReview
            && list.ownerID == userID
            && list.showReferences.contains(where: { $0.id == showID && $0.category == showCategory }) {
            await removeShowFromList(showID: showID, showCategory: showCategory, listID: list.id)
        }
    }
    
    /// Overload for removal by id+category (used by auto-remove).
    private func removeShowFromList(showID: Int, showCategory: Show.Category, listID: String) async {
        guard let userID = authService.getCurrentUserID() else {
            return
        }
        
        guard let listIndex = showLists.firstIndex(where: { $0.id == listID }) else {
            return
        }
        
        var updatedList = showLists[listIndex]
        guard updatedList.canEdit(userID: userID) else {
            return
        }
        
        updatedList.showReferences.removeAll { $0.id == showID && $0.category == showCategory }
        showLists[listIndex] = updatedList
        
        do {
            try await listService.updateList(updatedList, for: userID)
        } catch {
            await loadUserLists()
        }
    }
    
    // Backwards compatibility method that accepts just ID
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
        
        // Remove show from list (remove all references with this ID, regardless of category)
        updatedList.showReferences.removeAll { $0.id == showID }
        showLists[listIndex] = updatedList
        
        // Update in Firebase
        do {
            try await listService.updateList(updatedList, for: userID)
        } catch {
            // Revert on error - we can't fully revert without knowing the category
            // This is a limitation of backwards compatibility
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
            relationships = []

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
            relationships = []
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
        
        // Delete all of this user's relationships (incoming + outgoing + accepted)
        for relationship in relationships {
            if let other = relationship.otherUserID(currentUserID: userID) {
                try? await friendshipService.deleteRelationship(currentUserID: userID, otherUserID: other)
            }
        }

        // Delete Firebase Auth account (this must be last)
        try await authService.deleteAccount()

        // Clear local state
        isAuthenticated = false
        currentUser = nil
        userReviews = []
        showLists = []
        relationships = []
        
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

            if showID != nil {
                // When querying for a specific show, merge results to preserve optimistic updates
                // Use a dictionary to efficiently merge and update reviews
                var reviewsDict: [UUID: Review] = [:]

                // First, add all existing reviews (preserves local optimistic updates)
                for review in reviews {
                    reviewsDict[review.id] = review
                }

                // Then, update/add reviews from Firestore. Re-overlay the
                // current user's locally-tracked reaction so a stale read can't
                // drop a reaction they just set this session.
                for result in results {
                    var entry = result
                    applyMyReactionOverride(to: &entry)
                    reviewsDict[result.id] = entry
                }

                // Convert back to array, sorted by timestamp (newest first)
                let sortedReviews = Array(reviewsDict.values).sorted { $0.timestamp > $1.timestamp }
                reviews = sortedReviews
            } else {
                // When querying the feed (no showID), replace reviews with filtered results only
                // This ensures the UI shows only the filtered reviews
                var sortedReviews = results.sorted { $0.timestamp > $1.timestamp }
                for i in sortedReviews.indices {
                    applyMyReactionOverride(to: &sortedReviews[i])
                }
                reviews = sortedReviews
            }

            // Load author profiles (avatars) for the reviews we just fetched.
            await ensureProfilesLoaded(forAuthorIDs: reviews.compactMap { $0.authorID })
        } catch {
            // Handle error
        }
    }

    func loadUserProfile() async {
        do {
            let profile = try await profileService.fetchCurrentUser()
            currentUser = profile
            await loadUserReviews(for: profile.id)
            // Compute the persisted aggregates once for legacy profiles; no-op afterwards.
            await backfillCriticAggregateIfNeeded()
            await backfillGenreCountsIfNeeded()
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

    func updateAvatar(emoji: String?) async throws {
        guard let userID = authService.getCurrentUserID() else {
            throw NSError(domain: "NebRatingsStore", code: -1, userInfo: [NSLocalizedDescriptionKey: "No authenticated user"])
        }
        try await profileService.updateAvatar(userID: userID, emoji: emoji)
        await loadUserProfile()
    }

    func updateBio(_ bio: String?) async throws {
        guard let userID = authService.getCurrentUserID() else {
            throw NSError(domain: "NebRatingsStore", code: -1, userInfo: [NSLocalizedDescriptionKey: "No authenticated user"])
        }
        try await profileService.updateBio(userID: userID, bio: bio)
        await loadUserProfile()
    }

    /// Replaces the hand-picked favorite genres. Caps at 5 defensively —
    /// the picker UI enforces the same limit.
    func updateFavoriteGenres(_ genres: [String]) async throws {
        guard let userID = authService.getCurrentUserID() else {
            throw NSError(domain: "NebRatingsStore", code: -1, userInfo: [NSLocalizedDescriptionKey: "No authenticated user"])
        }
        try await profileService.updateFavoriteGenres(userID: userID, genres: Array(genres.prefix(5)))
        await loadUserProfile()
    }

    /// Sets or clears the favorite movie/show slot on the profile.
    func updateFavoriteTitle(_ title: FavoriteTitle?, field: FavoriteTitleField) async throws {
        guard let userID = authService.getCurrentUserID() else {
            throw NSError(domain: "NebRatingsStore", code: -1, userInfo: [NSLocalizedDescriptionKey: "No authenticated user"])
        }
        try await profileService.updateFavoriteTitle(userID: userID, field: field, title: title)
        await loadUserProfile()
    }

    func fetchReviews(for userID: String) async -> [Review] {
        do {
            return try await profileService.fetchReviews(for: userID)
        } catch {
            return []
        }
    }

    // MARK: - Friendships

    var friends: [Friendship] {
        relationships.filter { $0.status == .accepted }
    }

    var incomingRequests: [Friendship] {
        guard let me = authService.getCurrentUserID() else { return [] }
        return relationships.filter { $0.isIncomingRequest(for: me) }
    }

    var outgoingRequests: [Friendship] {
        guard let me = authService.getCurrentUserID() else { return [] }
        return relationships.filter { $0.isOutgoingRequest(for: me) }
    }

    func relationshipState(with otherUserID: String) -> RelationshipState {
        guard let me = authService.getCurrentUserID() else { return .none }
        guard let rel = relationships.first(where: { $0.members.contains(otherUserID) && $0.members.contains(me) }) else {
            return .none
        }
        switch rel.status {
        case .accepted: return .friends
        case .pending:  return rel.requesterID == me ? .outgoingRequest : .incomingRequest
        }
    }

    func loadRelationships() async {
        guard let userID = authService.getCurrentUserID() else {
            relationships = []
            return
        }
        do {
            relationships = try await friendshipService.fetchRelationships(for: userID)
        } catch {
            // Leave existing state on failure.
        }
    }

    func sendFriendRequest(to otherUserID: String) async {
        guard let me = authService.getCurrentUserID(), me != otherUserID else { return }
        // Optimistic add
        let placeholder = Friendship(
            id: Friendship.documentID(me, otherUserID),
            members: [me, otherUserID].sorted(),
            status: .pending,
            requesterID: me,
            createdAt: Date()
        )
        if !relationships.contains(where: { $0.id == placeholder.id }) {
            relationships.append(placeholder)
        }
        do {
            try await friendshipService.sendRequest(from: me, to: otherUserID)
        } catch {
            // Don't blindly revert — refetch to determine actual state.
            // (If the write truly failed, the refetch won't include the placeholder,
            // and the UI will correct itself. If it succeeded but threw for some
            // other reason, we'll keep the friendship.)
            await loadRelationships()
        }
    }

    func acceptFriendRequest(from otherUserID: String) async {
        guard let me = authService.getCurrentUserID() else { return }
        let id = Friendship.documentID(me, otherUserID)

        // Optimistic flip
        if let idx = relationships.firstIndex(where: { $0.id == id }) {
            let existing = relationships[idx]
            relationships[idx] = Friendship(
                id: existing.id,
                members: existing.members,
                status: .accepted,
                requesterID: existing.requesterID,
                createdAt: existing.createdAt
            )
        }

        do {
            try await friendshipService.acceptRequest(currentUserID: me, otherUserID: otherUserID)
        } catch {
            await loadRelationships()
        }
    }

    /// Used for declining incoming requests, canceling outgoing requests, and removing friends.
    func removeRelationship(with otherUserID: String) async {
        guard let me = authService.getCurrentUserID() else { return }
        let id = Friendship.documentID(me, otherUserID)
        let backup = relationships.first(where: { $0.id == id })
        relationships.removeAll { $0.id == id }
        do {
            try await friendshipService.deleteRelationship(currentUserID: me, otherUserID: otherUserID)
        } catch {
            if let backup { relationships.append(backup) }
        }
    }

    func fetchProfiles(userIDs: [String]) async -> [UserProfile] {
        do {
            return try await profileService.fetchProfiles(userIDs: userIDs)
        } catch {
            return []
        }
    }

    // MARK: - Author avatars & friend resolution (for review rows)

    /// Set of userIDs that are accepted friends of the current user.
    var friendIDs: Set<String> {
        guard let me = authService.getCurrentUserID() else { return [] }
        return Set(friends.compactMap { $0.otherUserID(currentUserID: me) })
    }

    /// Accepted-friend count for any profile. nil = query failed (hide the stat).
    func fetchFriendCount(for userID: String) async -> Int? {
        try? await friendshipService.fetchFriendCount(for: userID)
    }

    /// A single list by id, for deep links. Returns nil if the list doesn't
    /// exist or the viewer isn't allowed to see it (Firestore rules enforce
    /// visibility; we re-check locally as defense in depth).
    func fetchList(id: String) async -> ShowList? {
        guard let list = try? await listService.fetchList(id: id) else { return nil }
        let viewerID = authService.getCurrentUserID()
        let isFriend = isFriend(list.ownerID)
        return list.isVisible(to: viewerID, isFriendOfOwner: isFriend) ? list : nil
    }

    /// Another user's lists that the current viewer is allowed to see.
    /// Server queries are visibility-scoped; the client re-checks with
    /// `ShowList.isVisible` as defense in depth.
    func fetchVisibleLists(ownerID: String) async -> [ShowList] {
        let viewerIsFriend = isFriend(ownerID)
        let lists = (try? await listService.fetchVisibleLists(ownerID: ownerID, includeFriendsOnly: viewerIsFriend)) ?? []
        let viewerID = authService.getCurrentUserID()
        return lists.filter { $0.isVisible(to: viewerID, isFriendOfOwner: viewerIsFriend) }
    }

    // MARK: - Activity feed

    /// Fire-and-forget activity write. Feed events are best-effort — a
    /// failed write never blocks or fails the user action that produced it.
    private func recordActivity(_ activity: Activity) {
        Task { try? await activityService.record(activity) }
    }

    /// Records a list event — but only for lists other people can see.
    /// Private lists leave no trace in the feed. Document IDs are derived
    /// from the list/show, so re-saves are idempotent overwrites.
    private func recordListActivity(kind: Activity.Kind, list: ShowList, show: Show? = nil) {
        guard list.visibility != .privateList, let user = currentUser else { return }
        let id: String
        switch kind {
        case .createdList:
            id = "createdList_\(list.id)"
        case .addedToList:
            guard let show else { return }
            id = "addedToList_\(list.id)_\(show.id)"
        default:
            return
        }
        recordActivity(Activity(
            id: id,
            userID: user.id,
            username: user.username,
            kind: kind,
            timestamp: kind == .createdList ? list.createdAt : Date(),
            showID: show?.id,
            showTitle: show?.title,
            showCategory: show?.category,
            listID: list.id,
            listName: list.name,
            listVisibility: list.visibility
        ))
    }

    /// Everything the Activity tab shows, newest first:
    ///   • "rated" events derived from recent review documents
    ///   • persisted list / review-update events, filtered by list
    ///     visibility (friends-only events require friendship with the actor)
    /// Friends-first ordering is applied by the view, not here.
    func fetchActivityFeed(limit: Int = 100) async -> [Activity] {
        let since = Calendar.current.date(byAdding: .day, value: -45, to: Date()) ?? Date()
        async let reviewsFetch = reviewService.queryReviews(ReviewQuery(since: since, limit: 200))
        async let docsFetch = activityService.fetchRecent(limit: limit)

        let recentReviews = (try? await reviewsFetch) ?? []
        let docs = (try? await docsFetch) ?? []

        let ratedEvents = recentReviews
            .filter { $0.authorID != nil }
            .map(Activity.rated(from:))

        let viewerID = authService.getCurrentUserID()
        let visibleDocs = docs.filter { activity in
            guard let visibility = activity.listVisibility else {
                return true // non-list events (review updates)
            }
            switch visibility {
            case .publicList: return true
            case .friendsOnly: return activity.userID == viewerID || isFriend(activity.userID)
            case .privateList: return false
            }
        }

        return (ratedEvents + visibleDocs)
            .sorted { $0.timestamp > $1.timestamp }
    }

    func isFriend(_ userID: String?) -> Bool {
        guard let userID else { return false }
        return friendIDs.contains(userID)
    }

    /// Returns the profile for a userID — current user, or cached other user.
    func cachedProfile(for userID: String?) -> UserProfile? {
        guard let userID else { return nil }
        if userID == currentUser?.id { return currentUser }
        return profileCache[userID]
    }

    /// Fetches any author profiles not already cached so their avatars can render.
    func ensureProfilesLoaded(forAuthorIDs ids: [String]) async {
        let me = currentUser?.id
        let missing = Set(ids).subtracting(profileCache.keys).filter { $0 != me && !$0.isEmpty }
        guard !missing.isEmpty else { return }
        let fetched = await fetchProfiles(userIDs: Array(missing))
        for profile in fetched {
            profileCache[profile.id] = profile
        }
    }

    // MARK: - Critic harshness aggregate
    //
    // The gauge value is an average of (nebRating − tmdbRating). Rather than recompute it
    // (which requires a TMDB lookup per reviewed show) every time a profile is viewed, we
    // persist the running sum + count on the profile document and maintain it incrementally
    // on each review write. Reads then become O(1): delta = sum / count.

    /// Full recomputation from scratch — only used for one-time backfill of profiles that
    /// predate this feature. Returns the running sum and count of comparable reviews.
    private func computeCriticAggregate(reviews: [Review]) async -> (sum: Double, count: Int) {
        var uniqueShows: [Int: Show.Category] = [:]
        for review in reviews {
            uniqueShows[review.showID] = review.showCategory
        }
        guard !uniqueShows.isEmpty else { return (0, 0) }

        var ratings: [Int: Double] = [:]
        for (id, category) in uniqueShows {
            if let show = await fetchShowDetails(id: id, category: category),
               let rating = show.rating, rating > 0 {
                ratings[id] = rating
            }
        }

        var sum = 0.0
        var count = 0
        for review in reviews {
            if let tmdb = ratings[review.showID] {
                sum += review.nebRating - tmdb
                count += 1
            }
        }
        return (sum, count)
    }

    /// One-time compute+store for profiles that have never had the aggregate calculated.
    /// No-op once the aggregate exists, so this never runs on a normal profile view.
    private func backfillCriticAggregateIfNeeded() async {
        guard let user = currentUser, user.needsCriticBackfill,
              let me = authService.getCurrentUserID() else { return }

        let result = await computeCriticAggregate(reviews: userReviews)
        try? await profileService.setCriticAggregate(userID: me, sum: result.sum, count: result.count)
        applyLocalCriticAggregate(sum: result.sum, count: result.count)
    }

    /// Incrementally adjust the stored aggregate for a single review change.
    /// - oldRating: the review's previous rating (nil when adding a new review)
    /// - newRating: the review's new rating (nil when deleting)
    /// Only reviews whose show has a TMDB rating participate in the average.
    private func adjustCriticAggregate(showID: Int, showCategory: Show.Category, oldRating: Double?, newRating: Double?) async {
        guard let me = authService.getCurrentUserID() else { return }
        guard let show = await fetchShowDetails(id: showID, category: showCategory),
              let tmdb = show.rating, tmdb > 0 else { return }

        var sumDelta = 0.0
        var countDelta = 0
        if let newRating { sumDelta += (newRating - tmdb); countDelta += 1 }
        if let oldRating { sumDelta -= (oldRating - tmdb); countDelta -= 1 }
        guard sumDelta != 0 || countDelta != 0 else { return }

        try? await profileService.incrementCriticAggregate(userID: me, sumDelta: sumDelta, countDelta: countDelta)
        applyLocalCriticAggregate(
            sum: (currentUser?.criticDeltaSum ?? 0) + sumDelta,
            count: (currentUser?.criticDeltaCount ?? 0) + countDelta
        )
    }

    /// Mirror the aggregate locally so the gauge updates immediately without a profile reload.
    private func applyLocalCriticAggregate(sum: Double, count: Int) {
        // Copy-with preserves bio / favorites / joinDate / contentPreference —
        // rebuilding by hand here used to drop them and re-trigger onboarding.
        currentUser = currentUser?.withCriticAggregate(sum: sum, count: count)
    }

    // MARK: - Top genre aggregate
    //
    // Same persisted-aggregate strategy as critic harshness: rather than fetch
    // every reviewed show's genres on each profile view, we keep a running
    // per-genre review tally on the profile doc and maintain it incrementally.
    // Counting is per-review (mirrors the critic aggregate), so backfill and the
    // incremental adjusts stay consistent.

    /// Full recomputation from scratch — only used for the one-time backfill of
    /// profiles that predate this feature. Returns genre name → review count.
    private func computeGenreCounts(reviews: [Review]) async -> [String: Int] {
        var uniqueShows: [Int: Show.Category] = [:]
        for review in reviews {
            uniqueShows[review.showID] = review.showCategory
        }
        guard !uniqueShows.isEmpty else { return [:] }

        // Fetch each unique show once (cache makes repeat lookups cheap).
        var genresByShow: [Int: [String]] = [:]
        for (id, category) in uniqueShows {
            if let show = await fetchShowDetails(id: id, category: category) {
                genresByShow[id] = show.genres
            }
        }

        var counts: [String: Int] = [:]
        for review in reviews {
            for genre in genresByShow[review.showID] ?? [] {
                counts[genre, default: 0] += 1
            }
        }
        return counts
    }

    /// One-time compute+store for profiles that have never had the tally calculated.
    /// No-op once `genreCounts` exists, so this never runs on a normal profile view.
    private func backfillGenreCountsIfNeeded() async {
        guard let user = currentUser, user.needsGenreBackfill,
              let me = authService.getCurrentUserID() else { return }

        let counts = await computeGenreCounts(reviews: userReviews)
        try? await profileService.setGenreCounts(userID: me, counts: counts)
        applyLocalGenreCounts(counts)
    }

    /// Incrementally adjust the stored genre tally for a single review change.
    /// `delta` is +1 when adding a review, −1 when deleting one. Each of the
    /// show's genres is bumped by `delta`.
    private func adjustGenreCounts(showID: Int, showCategory: Show.Category, delta: Int) async {
        guard let me = authService.getCurrentUserID() else { return }
        guard let show = await fetchShowDetails(id: showID, category: showCategory),
              !show.genres.isEmpty else { return }

        var deltas: [String: Int] = [:]
        for genre in show.genres {
            deltas[genre, default: 0] += delta
        }

        try? await profileService.incrementGenreCounts(userID: me, deltas: deltas)

        var merged = currentUser?.genreCounts ?? [:]
        for (genre, d) in deltas {
            merged[genre, default: 0] += d
        }
        applyLocalGenreCounts(merged)
    }

    /// Mirror the tally locally so `topGenre` updates immediately without a reload.
    private func applyLocalGenreCounts(_ counts: [String: Int]) {
        currentUser = currentUser?.withGenreCounts(counts)
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
        // Check cache first, but validate the cached show matches the requested ID
        if let cached = showCache[id] {
            // Verify the cached show's ID matches what we're looking for
            if cached.id == id {
                // For series, only use cache if we have full details (numberOfSeasons); otherwise refetch
                if cached.category == .series, cached.numberOfSeasons == nil {
                    showCache.removeValue(forKey: id)
                } else {
                    return cached
                }
            } else {
                // Cached show doesn't match - remove it and refetch
                showCache.removeValue(forKey: id)
            }
        }
        
        // Fetch from API
        do {
            if let show = try await catalogService.fetchShowDetails(id: String(id), category: category) {
                // Verify the fetched show's ID matches before caching
                if show.id == id {
                    showCache[id] = show
                    return show
                }
            }
        } catch {
            // Error fetching show details
        }
        
        return nil
    }
    
    func fetchShowDetailsByTMDBID(tmdbID: Int, category: Show.Category) async -> Show? {
        // Check cache first, but validate the cached show matches the requested ID
        if let cached = showCache[tmdbID] {
            // Verify the cached show's ID matches what we're looking for
            if cached.id == tmdbID {
                // For series, only use cache if we have full details (numberOfSeasons); otherwise refetch
                if cached.category == .series, cached.numberOfSeasons == nil {
                    showCache.removeValue(forKey: tmdbID)
                } else {
                    return cached
                }
            } else {
                // Cached show doesn't match - remove it and refetch
                showCache.removeValue(forKey: tmdbID)
            }
        }
        
        // Fetch from API using TMDB ID
        do {
            if let show = try await catalogService.fetchShowDetails(id: String(tmdbID), category: category) {
                // Verify the fetched show's ID matches before caching
                if show.id == tmdbID {
                    showCache[show.id] = show
                    return show
                }
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
        // Check cache first, but validate the cached show matches the requested ID
        if let cached = showCache[review.showID] {
            // Verify the cached show's ID matches what we're looking for
            if cached.id == review.showID {
                return cached
            } else {
                // Cached show doesn't match - remove it
                showCache.removeValue(forKey: review.showID)
            }
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
                // Verify the fetched show's ID matches before caching
                if fullShow.id == review.showID {
                    showCache[review.showID] = fullShow
                }
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
            // Recommendation surface → respects the content preference.
            recommendations = preferenceScreened(results, preference: contentPreference)

            // Update cache
            for show in results {
                showCache[show.id] = show
            }
            // Warm recommendation posters so the row fills cleanly.
            ImageCache.shared.prefetch(recommendations.map(\.posterURL))
        } catch {
            // Handle error - could show error state
            // Show empty results on error rather than crashing
            recommendations = []
        }
    }
    
    /// YouTube trailers for a show, already priority-sorted by the service.
    /// Returns [] on any failure — the trailers section simply hides.
    func fetchTrailers(for show: Show) async -> [Trailer] {
        (try? await catalogService.fetchTrailers(tmdbID: show.id, category: show.category)) ?? []
    }

    /// Top-billed cast, fetched on demand and cached per title. [] on
    /// failure — the cast screen shows its empty state.
    func fetchCast(for show: Show) async -> [CastMember] {
        if let cached = castCache[show.id] {
            return cached
        }
        let cast = (try? await catalogService.fetchCast(tmdbID: show.id, category: show.category)) ?? []
        if !cast.isEmpty {
            castCache[show.id] = cast
        }
        return cast
    }

    /// Search that RETURNS results instead of mutating the shared Discover
    /// state (`shows` / `isSearchingShows`) — for embedded pickers like the
    /// favorite-title chooser, which must not disturb the Discover tab.
    func searchShowsDetached(query: String, category: Show.Category? = nil) async -> [Show] {
        (try? await catalogService.searchShows(query: query, category: category)) ?? []
    }

    // MARK: - Content preference

    /// The signed-in user's recommendation maturity level. Unset profiles
    /// behave as General Audience until the one-time prompt is answered.
    var contentPreference: ContentPreference {
        currentUser?.contentPreference ?? .generalAudience
    }

    /// True when the user has never chosen — drives the one-time prompt.
    var needsContentPreferencePrompt: Bool {
        currentUser != nil && currentUser?.contentPreference == nil
    }

    func updateContentPreference(_ preference: ContentPreference) async throws {
        guard let userID = authService.getCurrentUserID() else {
            throw NSError(domain: "NebRatingsStore", code: -1, userInfo: [NSLocalizedDescriptionKey: "No authenticated user"])
        }
        try await profileService.updateContentPreference(userID: userID, preference: preference)
        await loadUserProfile()
    }

    /// Injects the preference into a discover query: movie certification
    /// cap, excluded genres, and (family-friendly with no genres of its
    /// own) the spec's priority-genre fallback.
    private func preferenceAdjusted(_ filter: DiscoverFilter, preference: ContentPreference) -> DiscoverFilter {
        var adjusted = filter
        if filter.category == .movie {
            adjusted.movieCertificationCap = preference.movieCertificationCap
        }
        adjusted.excludedGenreIDs = preference.excludedGenreIDs(for: filter.category)
        if adjusted.genreIDs.isEmpty {
            let fallback = preference.fallbackGenreIDs(for: filter.category)
            if !fallback.isEmpty {
                adjusted.genreIDs = fallback
                adjusted.genreMatch = .any
            }
        }
        return adjusted
    }

    /// Client-side screen for endpoints TMDB can't filter server-side
    /// (trending, recommendation lists).
    private func preferenceScreened(_ shows: [Show], preference: ContentPreference) -> [Show] {
        shows.filter { preference.allows($0) }
    }

    // MARK: - Discover sections

    /// All Discover-section fetchers return [] on failure (section hides)
    /// and warm `showCache` so detail pushes and `show(for:)` stay cheap.
    private func cachingResult(_ shows: [Show]) -> [Show] {
        for show in shows where showCache[show.id] == nil {
            showCache[show.id] = show
        }
        return shows
    }

    /// Recommendation-surface discover. `preference` defaults to the
    /// signed-in user's; Watch Together passes the group's most
    /// restrictive. (Search does NOT go through here — it stays open.)
    func fetchDiscover(filter: DiscoverFilter, preference: ContentPreference? = nil) async -> [Show] {
        let effective = preference ?? contentPreference
        let adjusted = preferenceAdjusted(filter, preference: effective)
        let results = (try? await catalogService.fetchDiscover(filter: adjusted)) ?? []
        return cachingResult(preferenceScreened(results, preference: effective))
    }

    func fetchTrendingWeek(category: Show.Category? = nil) async -> [Show] {
        let results = (try? await catalogService.fetchTrendingWeekShows(category: category)) ?? []
        return cachingResult(preferenceScreened(results, preference: contentPreference))
    }

    /// Recommendations that return results without mutating the shared
    /// `recommendations` state (which belongs to the show-detail screen).
    func fetchRecommendationsDetached(tmdbID: Int,
                                      category: Show.Category,
                                      preference: ContentPreference? = nil) async -> [Show] {
        let results = (try? await catalogService.fetchRecommendations(tmdbID: tmdbID, category: category)) ?? []
        return cachingResult(preferenceScreened(results, preference: preference ?? contentPreference))
    }

    // MARK: - Discover feed (preloaded)

    /// Loads the entire Discover payload once, coalescing concurrent callers
    /// (splash preload + the view's own `.task`) onto a single fetch. Pass
    /// `force` to rebuild after something invalidates it (pull-to-refresh,
    /// content-preference change).
    func preloadDiscover(force: Bool = false) async {
        if force {
            discoverLoadTask?.cancel()
            discoverLoadTask = nil
            discoverFeed.isLoaded = false
        }
        if discoverFeed.isLoaded { return }
        if let task = discoverLoadTask {
            await task.value
            return
        }
        let task = Task { await loadDiscoverFeed() }
        discoverLoadTask = task
        await task.value
        discoverLoadTask = nil
    }

    private func loadDiscoverFeed() async {
        let now = Date()
        let calendar = Calendar.current
        let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: now)) ?? now
        let yearStart = calendar.date(from: calendar.dateComponents([.year], from: now)) ?? now
        let sixtyDaysAgo = calendar.date(byAdding: .day, value: -60, to: now) ?? now

        // All independent — fetched concurrently.
        async let seasonalFetch = fetchActiveSeasonalCollections()
        async let trendingFetch = fetchTrendingWeek()
        async let recentMoviesFetch = fetchDiscover(filter: DiscoverFilter(
            category: .movie, minVoteCount: 50, releasedAfter: sixtyDaysAgo, releasedBefore: now))
        async let recentTVFetch = fetchDiscover(filter: DiscoverFilter(
            category: .series, minVoteCount: 20, releasedAfter: sixtyDaysAgo, releasedBefore: now))
        async let gemMoviesFetch = fetchDiscover(filter: DiscoverFilter(
            category: .movie, minVoteAverage: 7.2, minVoteCount: 50, maxVoteCount: 500, sortBy: "vote_average.desc"))
        async let gemTVFetch = fetchDiscover(filter: DiscoverFilter(
            category: .series, minVoteAverage: 7.5, minVoteCount: 30, maxVoteCount: 300, sortBy: "vote_average.desc"))
        async let acclaimedMoviesFetch = fetchDiscover(filter: DiscoverFilter(
            category: .movie, minVoteCount: 5000, sortBy: "vote_average.desc"))
        async let acclaimedTVFetch = fetchDiscover(filter: DiscoverFilter(
            category: .series, minVoteCount: 2000, sortBy: "vote_average.desc"))
        async let monthRankings = fetchCommunityRankings(since: monthStart)
        async let yearRankings = fetchCommunityRankings(since: yearStart)

        // Personalized rows kick off now too (concurrent with everything).
        async let personalized = loadPersonalizedDiscoverRows()

        // ── Phase 1: the fast TMDB rows → render the page immediately, so it
        // never waits on the slower community-ranking resolution below. ──
        var feed = DiscoverFeed()
        feed.seasonal = await seasonalFetch
        feed.trendingWeek = await trendingFetch
        feed.recentlyReleased = interleaveShows(await recentMoviesFetch, await recentTVFetch)
        feed.hiddenGems = interleaveShows(await gemMoviesFetch, await gemTVFetch)
        feed.awardWinners = interleaveShows(await acclaimedMoviesFetch, await acclaimedTVFetch)
        feed.isLoaded = true
        discoverFeed = feed
        ImageCache.shared.prefetch((feed.trendingWeek + feed.recentlyReleased
            + feed.hiddenGems + feed.awardWinners).map(\.posterURL))

        // ── Phase 2: personalized rows fill into their slots as they arrive
        // (empty rows render nothing, so nothing flashes). ──
        let (byTitle, byShows, genreShows) = await personalized
        discoverFeed.becauseYouRatedTitle = byTitle
        discoverFeed.becauseYouRatedShows = byShows
        discoverFeed.favoriteGenreShows = genreShows
        ImageCache.shared.prefetch((byShows + genreShows).map(\.posterURL))

        // ── Phase 3: community rankings (slowest — resolves show details). ──
        let month = await monthRankings
        discoverFeed.highestRatedMonth = month.highestRated
        discoverFeed.mostReviewedMonth = month.mostReviewed
        let year = await yearRankings
        discoverFeed.highestRatedYear = year.highestRated
        ImageCache.shared.prefetch((month.highestRated + month.mostReviewed + year.highestRated).map(\.show.posterURL))
    }

    /// "Because You Rated X" + favorite-genre rows. Returns rather than
    /// mutating state so the caller can slot results in progressively.
    private func loadPersonalizedDiscoverRows() async -> (title: String?, shows: [Show], genreShows: [Show]) {
        var seedTitle: String?
        var seedShows: [Show] = []
        if let seed = userReviews.filter({ $0.nebRating >= 8 }).max(by: { lhs, rhs in
            lhs.nebRating != rhs.nebRating ? lhs.nebRating < rhs.nebRating : lhs.timestamp < rhs.timestamp
        }) {
            let recs = await fetchRecommendationsDetached(tmdbID: seed.showID, category: seed.showCategory)
            if !recs.isEmpty { seedTitle = seed.showTitle; seedShows = recs }
        }

        var genreShows: [Show] = []
        if let genres = currentUser?.favoriteGenres, !genres.isEmpty {
            let movieIDs = genres.compactMap { GenreCatalog.tmdbGenreIDs[$0] }
            let tvIDs = genres.compactMap { GenreCatalog.tmdbTVGenreIDs[$0] ?? GenreCatalog.tmdbGenreIDs[$0] }
            async let movies = fetchDiscover(filter: DiscoverFilter(
                category: .movie, genreIDs: movieIDs, genreMatch: .any, minVoteAverage: 6.8, minVoteCount: 300))
            async let tv = fetchDiscover(filter: DiscoverFilter(
                category: .series, genreIDs: Array(Set(tvIDs)), genreMatch: .any, minVoteAverage: 7.2, minVoteCount: 150))
            genreShows = interleaveShows(await movies, await tv)
        }
        return (seedTitle, seedShows, genreShows)
    }

    /// Merges movie + TV lists into one visually-mixed row, de-duped.
    private func interleaveShows(_ first: [Show], _ second: [Show]) -> [Show] {
        var result: [Show] = []
        var seen = Set<Int>()
        for index in 0..<max(first.count, second.count) {
            if index < first.count, seen.insert(first[index].id).inserted { result.append(first[index]) }
            if index < second.count, seen.insert(second[index].id).inserted { result.append(second[index]) }
        }
        return result
    }

    // MARK: - Seasonal collections

    /// The collections active *today*: the remote Firestore catalog when
    /// configured (server-side curation, no app update needed), otherwise
    /// the built-in schedule.
    func fetchActiveSeasonalCollections() async -> [SeasonalCollection] {
        let catalog = (try? await appConfigService.fetchSeasonalCollections()) ?? nil
        return SeasonalCatalog.active(from: catalog ?? SeasonalCatalog.builtIn)
    }

    /// Titles for one seasonal collection: keyword names are resolved to
    /// TMDB ids (cached per launch), then movie/TV discover queries run per
    /// the collection's recipe.
    func fetchShows(for collection: SeasonalCollection) async -> [Show] {
        // Resolve keywords once; misses are dropped silently.
        var keywordIDs: [Int] = []
        let unresolved = collection.keywords.filter { keywordIDCache[$0] == nil }
        if !unresolved.isEmpty {
            let resolved = (try? await catalogService.fetchKeywordIDs(names: unresolved)) ?? []
            // fetchKeywordIDs preserves input order for found names, but names
            // with no match are skipped — re-resolve one-by-one only when
            // counts diverge to keep the mapping honest.
            if resolved.count == unresolved.count {
                for (name, id) in zip(unresolved, resolved) {
                    keywordIDCache[name] = id
                }
            } else {
                for name in unresolved {
                    if let id = (try? await catalogService.fetchKeywordIDs(names: [name]))?.first {
                        keywordIDCache[name] = id
                    }
                }
            }
        }
        keywordIDs = collection.keywords.compactMap { keywordIDCache[$0] }

        // A keyword-driven collection whose keywords all failed to resolve
        // would degenerate into "all popular titles" — hide it instead.
        if !collection.keywords.isEmpty && keywordIDs.isEmpty && collection.movieGenreIDs.isEmpty && collection.tvGenreIDs.isEmpty {
            return []
        }

        var movies: [Show] = []
        var tv: [Show] = []
        if collection.includeMovies {
            movies = await fetchDiscover(filter: DiscoverFilter(
                category: .movie,
                genreIDs: collection.movieGenreIDs,
                keywordIDs: keywordIDs,
                minVoteAverage: collection.minVoteAverage,
                minVoteCount: collection.minVoteCount,
                sortBy: collection.sortBy
            ))
        }
        if collection.includeTV {
            tv = await fetchDiscover(filter: DiscoverFilter(
                category: .series,
                genreIDs: collection.tvGenreIDs,
                keywordIDs: keywordIDs,
                minVoteAverage: collection.minVoteAverage,
                minVoteCount: collection.minVoteCount.map { max(10, $0 / 3) },
                sortBy: collection.sortBy
            ))
        }

        var merged: [Show] = []
        var seen = Set<Int>()
        let maxCount = max(movies.count, tv.count)
        for index in 0..<maxCount {
            if index < movies.count, seen.insert(movies[index].id).inserted {
                merged.append(movies[index])
            }
            if index < tv.count, seen.insert(tv[index].id).inserted {
                merged.append(tv[index])
            }
        }
        return merged
    }

    // MARK: - Watch Together

    /// Builds the group for a Watch Together session: the signed-in user +
    /// the chosen friends, each with their reviews, profile, and the show
    /// ids sitting on lists the current user is allowed to see.
    func assembleGroupMembers(friendIDs: [String]) async -> [GroupMember] {
        var members: [GroupMember] = []

        if let me = currentUser {
            // Only lists I OWN count as *my* watchlist. Lists I merely
            // contribute to belong to their owner — counting those here
            // produced "it's on Cole's watchlist" for a friend's list.
            let myWatchlist = Set(
                showLists
                    .filter { $0.ownerID == me.id }
                    .flatMap { $0.showReferences.map(\.id) }
            )
            members.append(GroupMember(profile: me, reviews: userReviews, watchlistShowIDs: myWatchlist))
        }

        for friendID in friendIDs {
            guard let profile = await fetchProfile(userID: friendID) else { continue }
            let reviews = await fetchReviews(for: friendID)
            let visibleLists = await fetchVisibleLists(ownerID: friendID)
            members.append(GroupMember(
                profile: profile,
                reviews: reviews,
                watchlistShowIDs: Set(visibleLists.flatMap { $0.showReferences.map(\.id) })
            ))
        }
        return members
    }

    /// Gathers the candidate pool for the group from four directions:
    /// TMDB recs seeded by titles members loved, discover rows for the
    /// group's shared genres, hidden gems in those genres, and titles
    /// already sitting on members' watchlists.
    func gatherGroupCandidates(members: [GroupMember]) async -> [Show: Set<CandidateSource>] {
        var byID: [Int: (show: Show, sources: Set<CandidateSource>)] = [:]

        // The group's ceiling is its most restrictive member: if anyone is
        // Family Friendly, the whole session recommends family-friendly.
        let groupPreference = ContentPreference.mostRestrictive(
            members.map { $0.profile.contentPreference ?? .generalAudience }
        )

        func add(_ show: Show, _ source: CandidateSource) {
            // Every candidate passes the group ceiling, regardless of which
            // pipeline produced it (incl. watchlists and seeded recs).
            guard groupPreference.allows(show) else { return }
            if var existing = byID[show.id] {
                existing.sources.insert(source)
                byID[show.id] = existing
            } else {
                byID[show.id] = (show, [source])
            }
        }

        // ── Group genres: prominent for every member, else favorite union ─
        var commonGenres: [String] = []
        let prominentPerMember: [Set<String>] = members.map { member in
            var set = Set(member.profile.favoriteGenres ?? [])
            for (genre, share) in member.genreShares where share >= 0.12 {
                set.insert(genre)
            }
            return set
        }
        if let first = prominentPerMember.first {
            var intersection = first
            for set in prominentPerMember.dropFirst() {
                intersection.formIntersection(set)
            }
            commonGenres = Array(intersection.prefix(3))
        }
        if commonGenres.isEmpty {
            commonGenres = Array(Set(members.flatMap { $0.profile.favoriteGenres ?? [] }).prefix(3))
        }

        if !commonGenres.isEmpty {
            let movieIDs = commonGenres.compactMap { GenreCatalog.tmdbGenreIDs[$0] }
            let tvIDs = commonGenres.compactMap { GenreCatalog.tmdbTVGenreIDs[$0] ?? GenreCatalog.tmdbGenreIDs[$0] }
            let genreLabel = commonGenres[0]

            let movies = await fetchDiscover(filter: DiscoverFilter(
                category: .movie, genreIDs: movieIDs, genreMatch: .any,
                minVoteAverage: 6.8, minVoteCount: 300
            ), preference: groupPreference)
            let tv = await fetchDiscover(filter: DiscoverFilter(
                category: .series, genreIDs: Array(Set(tvIDs)), genreMatch: .any,
                minVoteAverage: 7.2, minVoteCount: 150
            ), preference: groupPreference)
            for show in (movies.prefix(15) + tv.prefix(15)) {
                add(show, .sharedGenre(genre: genreLabel))
            }

            // Hidden gems in the same taste space.
            let gems = await fetchDiscover(filter: DiscoverFilter(
                category: .movie, genreIDs: movieIDs, genreMatch: .any,
                minVoteAverage: 7.2, minVoteCount: 50, maxVoteCount: 500,
                sortBy: "vote_average.desc"
            ), preference: groupPreference)
            for show in gems.prefix(10) {
                add(show, .hiddenGem)
            }
        }

        // ── Seeds: titles members rated 8+, best first, max 4 seeds ───────
        let seeds = members
            .flatMap { member in member.reviews.filter { $0.nebRating >= 8 } }
            .sorted { $0.nebRating > $1.nebRating }
        var seenSeeds = Set<Int>()
        for seed in seeds {
            guard seenSeeds.count < 4, seenSeeds.insert(seed.showID).inserted else { continue }
            let recs = await fetchRecommendationsDetached(tmdbID: seed.showID, category: seed.showCategory, preference: groupPreference)
            for show in recs.prefix(10) {
                add(show, .seededBy(title: seed.showTitle))
            }
        }

        // ── Watchlist titles (resolved from cache where possible) ─────────
        var watchlistResolved = 0
        for member in members {
            for showID in member.watchlistShowIDs.prefix(20) {
                guard watchlistResolved < 15 else { break }
                if let cached = showCache[showID] {
                    add(cached, .watchlist(memberName: member.profile.username))
                    watchlistResolved += 1
                }
            }
        }

        return Dictionary(uniqueKeysWithValues: byID.values.map { ($0.show, $0.sources) })
    }

    // MARK: - Year in Review

    /// Gathers everything the Wrapped engine needs: the year's reviews,
    /// show details for them (cache-backed, capped), the user's list
    /// creation dates, and the most compatible friend.
    func buildYearInReview(year: Int) async -> YearInReviewStats {
        let calendar = Calendar.current
        let yearReviews = userReviews.filter {
            calendar.component(.year, from: $0.timestamp) == year
        }

        // Resolve show details for genres/decades/TMDB ratings. Capped so a
        // heavy year doesn't fire hundreds of requests; cache absorbs most.
        var shows: [Int: Show] = [:]
        var resolvedCount = 0
        for review in yearReviews {
            if let cached = showCache[review.showID], !cached.genres.isEmpty {
                shows[review.showID] = cached
                continue
            }
            guard resolvedCount < 60 else { continue }
            resolvedCount += 1
            if let show = await fetchShowDetailsByTMDBID(tmdbID: review.showID, category: review.showCategory) {
                shows[review.showID] = show
            }
        }

        // Most compatible friend (first 5 friends, best score wins).
        var bestFriend: (profile: UserProfile, score: Int)?
        if let me = authService.getCurrentUserID() {
            let friendIDs = friends.compactMap { $0.otherUserID(currentUserID: me) }.prefix(5)
            for friendID in friendIDs {
                guard let profile = await fetchProfile(userID: friendID) else { continue }
                let theirReviews = await fetchReviews(for: friendID)
                let report = CompatibilityEngine.report(
                    myReviews: userReviews,
                    theirReviews: theirReviews,
                    myProfile: currentUser,
                    theirProfile: profile
                )
                if report.score > (bestFriend?.score ?? -1) {
                    bestFriend = (profile, report.score)
                }
            }
        }

        let myListDates = showLists
            .filter { $0.ownerID == authService.getCurrentUserID() }
            .map(\.createdAt)

        return YearInReviewEngine.build(
            year: year,
            reviews: yearReviews,
            shows: shows,
            listCreationDates: myListDates,
            bestFriend: bestFriend
        )
    }

    // MARK: - Community rankings

    struct RankedShow: Identifiable {
        let show: Show
        let averageRating: Double
        let reviewCount: Int
        var id: Int { show.id }
    }

    /// NebRatings-community rankings since a given date: shows ranked by
    /// average neb rating and by review volume. One review fetch feeds both.
    /// Season-specific reviews count toward their parent show.
    func fetchCommunityRankings(since: Date, limit: Int = 10) async -> (highestRated: [RankedShow], mostReviewed: [RankedShow]) {
        let recent = (try? await reviewService.queryReviews(ReviewQuery(since: since, limit: 500))) ?? []
        guard !recent.isEmpty else { return ([], []) }

        struct Aggregate {
            var sum = 0.0
            var count = 0
            var title = ""
            var category = Show.Category.movie
        }
        var aggregates: [Int: Aggregate] = [:]
        for review in recent {
            var aggregate = aggregates[review.showID] ?? Aggregate()
            aggregate.sum += review.nebRating
            aggregate.count += 1
            aggregate.title = review.showTitle
            aggregate.category = review.showCategory
            aggregates[review.showID] = aggregate
        }

        let byRating = aggregates
            .sorted { lhs, rhs in
                let l = lhs.value.sum / Double(lhs.value.count)
                let r = rhs.value.sum / Double(rhs.value.count)
                if l != r { return l > r }
                return lhs.value.count > rhs.value.count
            }
            .prefix(limit)
        let byVolume = aggregates
            .sorted { lhs, rhs in
                if lhs.value.count != rhs.value.count { return lhs.value.count > rhs.value.count }
                return (lhs.value.sum / Double(lhs.value.count)) > (rhs.value.sum / Double(rhs.value.count))
            }
            .prefix(limit)

        // Resolve Shows (poster art etc.) for the union of both top lists —
        // cache-backed, so repeat visits don't refetch.
        var resolved: [Int: Show] = [:]
        let neededIDs = Set(byRating.map(\.key)).union(byVolume.map(\.key))
        for showID in neededIDs {
            guard let aggregate = aggregates[showID] else { continue }
            if let show = await fetchShowDetailsByTMDBID(tmdbID: showID, category: aggregate.category) {
                resolved[showID] = show
            }
        }

        func ranked<S: Sequence>(_ entries: S) -> [RankedShow] where S.Element == (key: Int, value: Aggregate) {
            entries.compactMap { entry in
                guard let show = resolved[entry.key] else { return nil }
                // Ranking rows live on Discover → content preference applies.
                guard contentPreference.allows(show) else { return nil }
                return RankedShow(
                    show: show,
                    averageRating: entry.value.sum / Double(entry.value.count),
                    reviewCount: entry.value.count
                )
            }
        }

        return (ranked(byRating), ranked(byVolume))
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
                    // User already has a review for this show/season - update it (updateReview handles auto-remove)
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
                        // User already has a review for this season - update it (updateReview handles auto-remove)
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
                // Auto-remove from lists with that setting (single-owner lists only)
                await performAutoRemoveFromLists(showID: showID, showCategory: show.category)
                // Incrementally update the persisted aggregates (new review)
                if author == currentUser?.username {
                    await adjustCriticAggregate(showID: showID, showCategory: show.category, oldRating: nil, newRating: rating)
                    await adjustGenreCounts(showID: showID, showCategory: show.category, delta: 1)
                }
                // Maybe show in-app review prompt after positive engagement
                await MainActor.run {
                    AppStoreReviewHelper.maybeRequestInAppReview(userReviewCount: userReviews.count)
                }
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
            // Auto-remove from lists with that setting (single-owner lists only)
            await performAutoRemoveFromLists(showID: review.showID, showCategory: review.showCategory)
            // Incrementally update the persisted critic-harshness aggregate (rating change)
            if review.author == currentUser?.username {
                await adjustCriticAggregate(showID: review.showID, showCategory: review.showCategory, oldRating: review.nebRating, newRating: rating)
            }
            // Maybe show in-app review prompt after positive engagement
            await MainActor.run {
                AppStoreReviewHelper.maybeRequestInAppReview(userReviewCount: userReviews.count)
            }
            // Feed event: "updated their review". Idempotent id — repeated
            // edits collapse to one (latest) event.
            if let user = currentUser, review.author == user.username {
                recordActivity(Activity(
                    id: "updatedReview_\(review.id.uuidString)",
                    userID: user.id,
                    username: user.username,
                    kind: .updatedReview,
                    timestamp: Date(),
                    showID: review.showID,
                    showTitle: review.showTitle,
                    showCategory: review.showCategory,
                    rating: rating,
                    season: season ?? review.season
                ))
            }
        } catch {
            // Error updating review
        }
    }

    func updateReview(_ review: Review, comment: String, rating: Double) {
        updateReview(review, comment: comment, rating: rating, newSeason: review.season)
    }

    /// Update including the ability to change the season target (nil = entire show).
    func updateReview(_ review: Review, comment: String, rating: Double, newSeason: Int?) {
        // Create updated review with new comment, rating, and explicit season target
        let updatedReview = Review(
            id: review.id,
            showID: review.showID,
            showTitle: review.showTitle,
            showCategory: review.showCategory,
            author: review.author,
            comment: comment.trimmingCharacters(in: .whitespacesAndNewlines),
            nebRating: rating,
            timestamp: review.timestamp, // Keep original timestamp
            season: newSeason
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
                // Auto-remove from lists with that setting (single-owner lists only)
                await performAutoRemoveFromLists(showID: review.showID, showCategory: review.showCategory)
                // Incrementally update the persisted critic-harshness aggregate (rating change).
                // A season-only edit leaves the rating unchanged, so this is a no-op in that case.
                if review.author == currentUser?.username {
                    await adjustCriticAggregate(showID: review.showID, showCategory: review.showCategory, oldRating: review.nebRating, newRating: rating)
                }
                // Maybe show in-app review prompt after positive engagement
                await MainActor.run {
                    AppStoreReviewHelper.maybeRequestInAppReview(userReviewCount: userReviews.count)
                }
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
    
    /// The current user's own reaction per review, tracked locally so it
    /// survives Firestore re-reads. Keyed by reviewID; the wrapped value is the
    /// emoji, or `nil` when the user explicitly cleared their reaction. Every
    /// `queryReviews` re-overlays this onto fetched results, so a stale or
    /// eventually-consistent read can never drop a reaction the user just set.
    private var myReactionOverrides: [UUID: String?] = [:]

    /// Overlay the current user's locally-tracked reaction (if any) onto a
    /// freshly fetched review, so a stale server read can't drop a reaction the
    /// user just set/cleared this session.
    private func applyMyReactionOverride(to review: inout Review) {
        guard let myID = authService.getCurrentUserID(),
              let override = myReactionOverrides[review.id] else { return }
        if let emoji = override {
            review.reactions[myID] = emoji
        } else {
            review.reactions.removeValue(forKey: myID)
        }
    }

    /// Sets or clears the current user's reaction on a review. Pass `emoji: nil`
    /// to remove the reaction.
    ///
    /// The reaction is recorded in `myReactionOverrides` (durable local state)
    /// and applied immediately, then persisted to Firestore in the background.
    /// We deliberately do NOT revert on a failed write: the reaction stays put
    /// in the UI regardless of the write outcome, so it never "appears then
    /// vanishes." A failed write simply means it won't survive an app reload —
    /// see `firestore.rules` for the rule that lets non-author reactions persist.
    func setReaction(emoji: String?, on review: Review) async {
        guard let myID = authService.getCurrentUserID() else { return }

        // Record my reaction in the durable local override map, then apply it
        // for immediate optimistic UI. The override is the source of truth for
        // *my* reaction until the app reloads, so a stale server read can't
        // drop it out from under me.
        //
        // The local apply is wrapped in an explicit `withAnimation` transaction
        // — NOT a scoped `.animation(value:)` on the bar — because this is the
        // only mechanism that reliably drives the reaction pill insert/remove
        // transitions in EVERY container the bar lives in. A scoped animation
        // animated removals inside a plain `LazyVStack` (the Reviews tab) but
        // was dropped by `List` rows (the show-detail carousel) and never fired
        // for insertions arriving via the emoji keyboard. An explicit
        // transaction propagates into List row content and wraps both the
        // keyboard-driven add and the tap-driven remove, so the pop-in and
        // shrink-out play consistently everywhere.
        myReactionOverrides[review.id] = emoji
        withAnimation(.spring(response: 0.35, dampingFraction: 0.55)) {
            applyReactionLocally(reviewID: review.id, userID: myID, emoji: emoji)
        }

        do {
            try await reviewService.setReaction(reviewID: review.id, userID: myID, emoji: emoji)
        } catch {
            print("⚠️ setReaction failed to persist (kept locally): \(error)")
        }
    }

    /// Mutate the reactions map on every local copy of the review (both
    /// `reviews` and `userReviews`). Passing `emoji: nil` removes the key.
    private func applyReactionLocally(reviewID: UUID, userID: String, emoji: String?) {
        func mutate(_ array: inout [Review]) {
            guard let idx = array.firstIndex(where: { $0.id == reviewID }) else { return }
            var updated = array[idx]
            if let emoji {
                updated.reactions[userID] = emoji
            } else {
                updated.reactions.removeValue(forKey: userID)
            }
            array[idx] = updated
        }
        mutate(&reviews)
        mutate(&userReviews)
    }

    func deleteReview(_ review: Review) {
        // Remove from local state immediately for optimistic UI
        reviews = reviews.filter { $0.id != review.id }
        
        // Remove from user reviews if it's the current user
        if let user = currentUser, review.author == user.username {
            userReviews = userReviews.filter { $0.id != review.id }
        }
        
        // Capture whether this is the current user's review before the async work.
        let isOwnReview = review.author == currentUser?.username

        // Delete from Firestore in background
        Task {
            do {
                try await reviewService.delete(review: review)
                // Refresh reviews to ensure consistency with Firestore
                await queryReviews(showID: review.showID)
                // Incrementally update the persisted aggregates (removal)
                if isOwnReview {
                    await adjustCriticAggregate(showID: review.showID, showCategory: review.showCategory, oldRating: review.nebRating, newRating: nil)
                    await adjustGenreCounts(showID: review.showID, showCategory: review.showCategory, delta: -1)
                }
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
