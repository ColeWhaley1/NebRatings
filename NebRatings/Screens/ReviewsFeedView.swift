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
    @State private var reviewToEdit: Review?
    @State private var displayedReviewCount: Int = 5
    @State private var cachedReviews: [Review] = []
    @State private var navigationPath = NavigationPath()

    var body: some View {
        NavigationStack(path: $navigationPath) {
            List {
                filterSection
                reviewsSection
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Community Nebs")
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
            .onChange(of: searchText) { _, _ in
                displayedReviewCount = 5
                performQuery()
            }
            .onChange(of: categoryFilter) { _, _ in
                displayedReviewCount = 5
                performQuery()
            }
            .onChange(of: minimumRating) { _, _ in
                displayedReviewCount = 5
                performQuery()
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
        Section("Recent Reviews") {
            // Only show loading indicator if we have no reviews yet (initial load)
            if store.isQueryingReviews && displayableReviews.isEmpty {
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
                .padding()
            } else if displayableReviews.isEmpty {
                ContentUnavailableView("No reviews match", systemImage: "text.magnifyingglass", description: Text("Try adjusting the filters."))
            } else {
                // Show existing reviews even while loading new ones to prevent flicker
                ForEach(Array(displayableReviews.prefix(displayedReviewCount))) { review in
                    // Add ID for stable animations
                    let show = store.show(for: review)
                    let isOwnReview = store.currentUser?.username == review.author
                    let authorProfile = store.cachedProfile(for: review.authorID)
                    if let show = show {
                        ReviewCard(review: review,
                                   showTitle: show.title,
                                   showCategory: show.category,
                                   isOwnReview: isOwnReview,
                                   authorAvatarEmoji: authorProfile?.avatarEmoji,
                                   isFriend: store.isFriend(review.authorID),
                                   onTap: {
                                       navigationPath.append(ShowWithContext(show: show, initialSeasonFilter: review.season))
                                   },
                                   useLighterBackground: true
                                   )
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            if isOwnReview {
                                Button {
                                    store.deleteReview(review)
                                } label: {
                                    Image(systemName: "trash.fill")
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundStyle(.white)
                                        .frame(width: 44, height: 44)
                                        .background(Color.red, in: Circle())
                                }
                                .tint(.clear)

                                Button {
                                    reviewToEdit = review
                                } label: {
                                    Image(systemName: "pencil")
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundStyle(.white)
                                        .frame(width: 44, height: 44)
                                        .background(Color.blue, in: Circle())
                                }
                                .tint(.clear)
                            }
                        }
                    }
                }
                .listRowSeparator(.hidden)
                .animation(.default, value: displayableReviews.count)
                .animation(.default, value: displayedReviewCount)
                
                // Show loading indicator overlay if querying and we have reviews
                if store.isQueryingReviews && !displayableReviews.isEmpty {
                    HStack {
                        Spacer()
                        ProgressView()
                            .padding(.vertical, 8)
                        Spacer()
                    }
                }
                
                // Show Less button if showing more than default (5)
                if displayedReviewCount > 5 {
                    Button(action: {
                        displayedReviewCount = max(5, displayedReviewCount - 5)
                    }) {
                        HStack {
                            Spacer()
                            Text("Show Less")
                                .font(.subheadline)
                                .foregroundStyle(.gray)
                            Image(systemName: "chevron.up")
                                .font(.caption)
                                .foregroundStyle(.gray)
                            Spacer()
                        }
                        .padding(.vertical, 8)
                    }
                    .buttonStyle(.plain)
                }
                
                // Show More button if there are more reviews
                if displayableReviews.count > displayedReviewCount {
                    Button(action: {
                        displayedReviewCount += 5
                    }) {
                        HStack {
                            Spacer()
                            Text("Show More")
                                .font(.subheadline)
                                .foregroundStyle(.gray)
                            Image(systemName: "chevron.down")
                                .font(.caption)
                                .foregroundStyle(.gray)
                            Spacer()
                        }
                        .padding(.vertical, 8)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .sheet(item: $reviewToEdit) { review in
            EditReviewView(review: review)
                .environment(store)
        }
    }
    
    /// Returns the reviews that should be displayed.
    /// When searching (searchText is not empty), returns all matching reviews.
    /// When not searching, returns max 10 most recent reviews.
    /// Uses cached reviews while loading to prevent flicker.
    private var displayableReviews: [Review] {
        // While querying, use cached reviews if available to prevent flicker
        let allReviews = store.isQueryingReviews && !cachedReviews.isEmpty ? cachedReviews : store.reviews

        // Update cache when not querying
        if !store.isQueryingReviews {
            cachedReviews = store.reviews
        }

        // Friends' reviews bubble to the top, then most-recent first.
        let sorted = sortFriendsFirst(allReviews)

        // If searching, show all matching reviews
        if !searchText.isEmpty {
            return sorted
        }

        // When not searching, limit to 10 (friends prioritized within that window)
        return Array(sorted.prefix(10))
    }

    /// Friends' reviews first, then by recency.
    private func sortFriendsFirst(_ reviews: [Review]) -> [Review] {
        reviews.sorted { lhs, rhs in
            let lf = store.isFriend(lhs.authorID)
            let rf = store.isFriend(rhs.authorID)
            if lf != rf { return lf }
            return lhs.timestamp > rhs.timestamp
        }
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
