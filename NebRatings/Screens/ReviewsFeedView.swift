//
//  ReviewsFeedView.swift
//  NebRatings
//
//  Created by Cole Whaley on 11/29/25.
//

import SwiftUI

struct ReviewsFeedView: View {
    enum CategoryFilter: String, CaseIterable, Identifiable {
        case all = "All"
        case movies = "Movies"
        case series = "Series"

        var id: String { rawValue }

        var category: Show.Category? {
            switch self {
            case .all: return nil
            case .movies: return .movie
            case .series: return .series
            }
        }
    }

    @Environment(NebRatingsStore.self) private var store: NebRatingsStore
    @State private var searchText = ""
    @State private var categoryFilter: CategoryFilter = .all
    @State private var minimumRating: Double = 0
    @State private var queryTask: Task<Void, Never>?
    @State private var currentReviewPage: Int = 0
    @State private var navigationPath = NavigationPath()
    /// Order-only snapshot of the friend-filtered feed. Captured on page load
    /// and any time the *set* of reviews changes (new query, deletion, etc.).
    /// Reaction counts don't trigger a re-sort — we look up the live review
    /// (with current reactions) by id in `displayableReviews`, but the
    /// position in the list is frozen so cards don't shuffle while you read.
    @State private var sortedSnapshot: [Review] = []

    private let reviewsPerPage = 5

    var body: some View {
        NavigationStack(path: $navigationPath) {
            List {
                filterSection
                reviewsSection
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Friends' Nebs")
            .navigationDestination(for: Show.self) { show in
                ShowDetailView(show: show)
            }
            .navigationDestination(for: ShowWithContext.self) { ctx in
                ShowDetailView(show: ctx.show, initialSeasonFilter: ctx.initialSeasonFilter)
            }
            .searchable(text: $searchText, prompt: "Search reviews")
            .onAppear {
                performQuery()
            }
            .task {
                // Initial sort snapshot on first load. Subsequent re-sorts
                // happen only when the *set* of reviews changes (see below).
                refreshSnapshot()
            }
            .onChange(of: searchText) { _, _ in
                currentReviewPage = 0
                performQuery()
            }
            .onChange(of: categoryFilter) { _, _ in
                currentReviewPage = 0
                performQuery()
            }
            .onChange(of: minimumRating) { _, _ in
                currentReviewPage = 0
                performQuery()
            }
            .onChange(of: store.reviews.map(\.id)) { _, _ in
                // Re-sort when reviews are added/removed (or a new query
                // returns a different set). Reaction-count changes leave the
                // id list unchanged, so they don't trigger this — cards stay
                // in place while the user is looking at them.
                refreshSnapshot()
            }
        }
    }
    
    private func performQuery() {
        // Cancel previous query task
        queryTask?.cancel()
        
        // Debounce query - wait 0.3 seconds after filter changes
        queryTask = Task {
            try? await Task.sleep(nanoseconds: 300_000_000) // 0.3 seconds
            
            guard !Task.isCancelled else { return }
            
            let searchQuery = searchText.isEmpty ? nil : searchText
            await store.queryReviews(
                searchText: searchQuery,
                category: categoryFilter.category,
                minimumRating: minimumRating > 0 ? minimumRating : nil
            )
        }
    }

    private var filterSection: some View {
        Section("Filters") {
            Picker("Category", selection: $categoryFilter) {
                ForEach(CategoryFilter.allCases) { filter in
                    Text(filter.rawValue).tag(filter)
                }
            }
            .pickerStyle(.segmented)

            VStack(alignment: .leading) {
                Text("Minimum rating: \(minimumRating, specifier: "%.1f") nebs")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Slider(value: $minimumRating, in: 0...10, step: 0.1)
                    .tint(.purple)
            }
        }
    }

    private var reviewsSection: some View {
        Section {
            // Only show loading indicator if we have no reviews yet (initial load)
            if store.isQueryingReviews && displayableReviews.isEmpty {
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
                .padding()
            } else if !store.isQueryingReviews && store.friends.isEmpty {
                // Distinct empty state: the feed is empty because the user has no
                // friends at all (not because filters/search excluded everything).
                ContentUnavailableView(
                    "No friends yet",
                    systemImage: "person.2",
                    description: Text("Add friends from the Friends tab to see their reviews here.")
                )
            } else if displayableReviews.isEmpty {
                ContentUnavailableView(
                    "Nothing from your friends",
                    systemImage: "text.bubble",
                    description: Text("Try clearing filters or check back after your friends post.")
                )
            } else {
                let allReviews = displayableReviews
                let pageCount = ReviewPagination.pageCount(for: allReviews.count, pageSize: reviewsPerPage)

                // Pager chevrons (only when there's more than one page)
                if pageCount > 1 {
                    HStack {
                        Spacer()
                        ReviewPagerChevrons(pageCount: pageCount, currentPage: $currentReviewPage)
                    }
                    .listRowSeparator(.hidden)
                }

                PaginatedReviewsCarousel(
                    reviews: allReviews,
                    pageSize: reviewsPerPage,
                    currentPage: $currentReviewPage
                ) { review in
                    feedCard(for: review)
                }
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets())
                // NOTE: deliberately no background-query spinner row here. The
                // cards are already on screen during a refresh; adding a spinner
                // row below them grows the list for ~0.3s and then collapses it,
                // which read as a height "glitch" when entering the tab.
            }
        } header: {
            HStack(spacing: 8) {
                Text("From Your Friends")
                if !displayableReviews.isEmpty {
                    ReviewCountBadge(count: displayableReviews.count)
                        .textCase(nil) // Section headers force uppercase; the badge is its own thing.
                }
                Spacer()
            }
        }
    }

    @ViewBuilder
    private func feedCard(for review: Review) -> some View {
        if let show = store.show(for: review) {
            let authorProfile = store.cachedProfile(for: review.authorID)
            ReviewCard(review: review,
                       showTitle: show.title,
                       showCategory: show.category,
                       isOwnReview: store.currentUser?.username == review.author,
                       authorAvatarEmoji: authorProfile?.avatarEmoji,
                       isFriend: store.isFriend(review.authorID),
                       onTap: {
                           navigationPath.append(ShowWithContext(show: show, initialSeasonFilter: review.season))
                       },
                       useLighterBackground: true,
                       currentUserID: store.currentUser?.id,
                       onReact: { emoji in
                           Task { await store.setReaction(emoji: emoji, on: review) }
                       })
        }
    }
    
    /// Returns the reviews that should be displayed.
    ///
    /// Order is fixed by `sortedSnapshot`, which is captured on page load
    /// and re-captured when reviews are added/removed/refreshed. The live
    /// review (with current reactions) is looked up by id, so reaction
    /// changes update the pills in place — but never reshuffle the cards.
    /// Pagination is handled downstream by `PaginatedReviewsCarousel`.
    private var displayableReviews: [Review] {
        // Live lookup table from current store state — so reactions update
        // in real time even though list order is frozen.
        let liveByID: [UUID: Review] = Dictionary(
            uniqueKeysWithValues: store.reviews.map { ($0.id, $0) }
        )
        // Resolve each snapshot id against the live store; drop any that
        // have since been deleted upstream.
        return sortedSnapshot.compactMap { liveByID[$0.id] }
    }

    /// Recompute the order snapshot from the current store state. Called
    /// only on page load and when the underlying review set changes.
    ///
    /// The feed always shows friends' reviews most-recent-first. (This tab
    /// intentionally does NOT sort by reaction count — that ordering is used
    /// elsewhere, not here.)
    private func refreshSnapshot() {
        // While querying, hold onto the existing snapshot — prevents the feed
        // from going empty mid-filter-change.
        if store.isQueryingReviews && !sortedSnapshot.isEmpty { return }

        let friendsOnly = store.reviews.filter { store.isFriend($0.authorID) }
        sortedSnapshot = friendsOnly.sorted { $0.timestamp > $1.timestamp }
    }
}

#Preview {
    let store = NebRatingsStore()
    // Populate with sample reviews for preview
    store.reviews = Review.sampleData
    
    return ReviewsFeedView()
        .environment(store)
}

#Preview("With Movie Filter") {
    let store = NebRatingsStore()
    // Filter to show only movie reviews
    store.reviews = Review.sampleData.filter { $0.showCategory == .movie }
    
    return ReviewsFeedView()
        .environment(store)
}

#Preview("With High Rating Filter") {
    let store = NebRatingsStore()
    // Filter to show only high-rated reviews
    store.reviews = Review.sampleData.filter { $0.nebRating >= 4.5 }
    
    return ReviewsFeedView()
        .environment(store)
}

#Preview("Empty State") {
    let store = NebRatingsStore()
    // Empty reviews to show empty state
    store.reviews = []
    
    return ReviewsFeedView()
        .environment(store)
}
