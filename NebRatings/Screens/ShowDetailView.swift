//
//  ShowDetailView.swift
//  NebRatings
//
//  Created by Cole Whaley on 11/29/25.
//

import SwiftUI

// PreferenceKey to measure review card heights
struct ReviewHeightPreferenceKey: PreferenceKey {
    static var defaultValue: [UUID: CGFloat] = [:]
    
    static func reduce(value: inout [UUID: CGFloat], nextValue: () -> [UUID: CGFloat]) {
        value.merge(nextValue()) { _, new in new }
    }
}

struct ShowDetailView: View {
    @Environment(NebRatingsStore.self) private var store: NebRatingsStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    let show: Show

    @State private var newComment = ""
    @State private var newNebs: Double = 5 // Default to 5 out of 10
    @State private var detailedShow: Show?
    @State private var isProvidersExpanded = false
    @FocusState private var isCommentFocused: Bool
    @State private var reviewToEdit: Review?
    @State private var reviewHeights: [UUID: CGFloat] = [:]
    @State private var currentReviewPage: Int = 0
    @State private var expandedReview: Review?
    @State private var showingListPicker = false
    @State private var selectedListIDs: Set<String> = []
    @State private var selectedListID: String?
    @State private var selectedSeason: Int? = nil // nil means "Entire Show" (for adding reviews)
    @State private var filterSeason: Int? = nil // nil means "Entire Show" (for filtering reviews display, defaults to nil)
    
    private var displayShow: Show {
        detailedShow ?? show
    }

    private func reviews() -> [Review] {
        // Use displayShow.id to ensure we use the correct ID even if detailedShow was loaded
        let showID = displayShow.id
        var filtered = store.reviews.filter { $0.showID == showID }
        
        // Filter by season if a season filter is selected
        if let filterSeason = filterSeason {
            filtered = filtered.filter { $0.season == filterSeason }
        } else {
            // Default to showing reviews for entire show (season == nil)
            filtered = filtered.filter { $0.season == nil }
        }
        
        
        // Sort reviews: user's review first, then by timestamp (newest first)
        let currentUserName = store.currentUser?.username
        let sorted = filtered.sorted { review1, review2 in
            let isReview1Own = review1.author == currentUserName
            let isReview2Own = review2.author == currentUserName
            
            // User's own review always comes first
            if isReview1Own && !isReview2Own {
                return true
            }
            if !isReview1Own && isReview2Own {
                return false
            }
            
            // If both are own reviews or both are not, sort by timestamp (newest first)
            return review1.timestamp > review2.timestamp
        }
        
        // Return all reviews (no limit, pagination handled in UI)
        return sorted
    }
    
    private func userHasReviewForSeason(_ season: Int?) -> Bool {
        guard let currentUser = store.currentUser else { return false }
        let showID = displayShow.id
        return store.reviews.contains { review in
            review.showID == showID && review.author == currentUser.username && review.season == season
        }
    }
    
    private func userReviewForSeason(_ season: Int?) -> Review? {
        guard let currentUser = store.currentUser else { return nil }
        let showID = displayShow.id
        return store.reviews.first { review in
            review.showID == showID && review.author == currentUser.username && review.season == season
        }
    }
    
    private func calculateTotalHeight(for reviews: [Review]) -> CGFloat {
        let totalHeight = reviews.reduce(0.0) { total, review in
            // Height already includes row insets from the preference
            let rowHeight = reviewHeights[review.id] ?? 176 // Fallback: 160 card + 16 insets
            return total + rowHeight
        }
        return totalHeight
    }
    

    private var yearFormatted: String {
        return "\(displayShow.year)"
    }
    
    private var communityAverage: Double {
        let showID = displayShow.id
        // Always only include reviews for the entire show (season == nil)
        // This is the overall show average shown in the header
        let entireShowReviews = store.reviews.filter { 
            $0.showID == showID && $0.season == nil 
        }
        guard !entireShowReviews.isEmpty else { return 0 }
        let total = entireShowReviews.reduce(0.0) { $0 + $1.nebRating }
        return total / Double(entireShowReviews.count)
    }
    
    private var communityReviewCount: Int {
        let showID = displayShow.id
        // Always only count reviews for the entire show (season == nil)
        return store.reviews.filter { 
            $0.showID == showID && $0.season == nil 
        }.count
    }
    
    private var averageRatingForFilteredSeason: Double? {
        let showID = displayShow.id
        var filteredReviews = store.reviews.filter { $0.showID == showID }
        
        // Filter by the selected season (or entire show if nil)
        if let filterSeason = filterSeason {
            filteredReviews = filteredReviews.filter { $0.season == filterSeason }
        } else {
            filteredReviews = filteredReviews.filter { $0.season == nil }
        }
        
        guard !filteredReviews.isEmpty else { return nil }
        let total = filteredReviews.reduce(0.0) { $0 + $1.nebRating }
        return total / Double(filteredReviews.count)
    }
    
    private func ratingEmoji(for rating: Double) -> String? {
        // Ratings are on 0-10 scale
        if rating >= 8.0 {
            return "🔥" // 8.0 or better - Fire
        } else if rating <= 4.0 {
            return "🤮" // 4.0 or worse - Throw up
        }
        return nil // No emoji for values in between
    }
    
    private func displayedRating(for rating: Double) -> Double {
        // Ratings are stored and displayed on 0-10 scale directly
        return rating
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // Backdrop image - only show if backdrop exists
                if let backdropURL = displayShow.backdropURL, !backdropURL.isEmpty {
                    AsyncImageView(urlString: backdropURL)
                        .frame(height: 250)
                        .frame(maxWidth: .infinity)
                        .clipped()
                }
                
                HStack(spacing: 20) {
                    Spacer()
                        .frame(width: 20)
                    VStack(alignment: .leading, spacing: 24) {
                        header
                        Divider()
                            .background(Color(.separator))
                        reviewsSection
                        Divider()
                            .background(Color(.separator))
                        addReviewSection
                        Divider()
                            .background(Color(.separator))
                        recommendationsSection
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    Spacer()
                        .frame(width: 20)
                }
                .padding(.vertical, 20)
            }
        }
        .background(
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture {
                    isCommentFocused = false
                }
        )
        .scrollContentBackground(.hidden)
        .background(Color(.systemGroupedBackground))
        .navigationTitle(displayShow.title)
        .navigationBarTitleDisplayMode(.inline)
        .scrollDismissesKeyboard(.interactively)
        .task {
            await loadShowDetails()
            await loadShowReviews()
            await loadRecommendations()
            await store.loadUserLists()
            // Set default selected list to "To Watch"
            if selectedListID == nil {
                selectedListID = store.showLists.first(where: { $0.isDefault })?.id ?? store.showLists.first?.id
            }
        }
        .onChange(of: store.showLists) { _, _ in
            // Update selectedListID if current selection no longer exists
            if selectedListID != nil && !store.showLists.contains(where: { $0.id == selectedListID }) {
                selectedListID = store.showLists.first(where: { $0.isDefault })?.id ?? store.showLists.first?.id
            } else if selectedListID == nil && !store.showLists.isEmpty {
                selectedListID = store.showLists.first(where: { $0.isDefault })?.id ?? store.showLists.first?.id
            }
        }
    }
    
    private func loadShowDetails() async {
        // show.id is now the TMDB ID; fetch details when missing (empty genres or, for series, missing numberOfSeasons)
        let needsDetails = show.genres.isEmpty
            || (show.category == .series && show.numberOfSeasons == nil)
        if needsDetails {
            if let detailed = await store.fetchShowDetailsByTMDBID(tmdbID: show.id, category: show.category) {
                detailedShow = detailed

                // Now requery reviews with the correct id
                await loadShowReviews()
                await loadRecommendations()
            }
        }
    }

    
    private func loadShowReviews() async {
        // Use displayShow.id directly - it's now the TMDB ID
        let showID = displayShow.id
        await store.queryReviews(showID: showID)
    }
    
    private func loadRecommendations() async {
        await store.loadRecommendations(for: displayShow)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Poster and basic info in a row
            HStack(alignment: .top, spacing: 16) {
                // Poster - only show if poster exists
                if displayShow.posterURL != nil {
                    AsyncImageView(urlString: displayShow.posterURL)
                        .frame(width: 100, height: 150)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color(.separator), lineWidth: 1)
                        )
                }
                
                // Basic info column
                VStack(alignment: .leading, spacing: 8) {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 6) {
                            Image(systemName: "calendar")
                                .foregroundStyle(.secondary)
                                .font(.subheadline)
                                .frame(width: 20, alignment: .leading)
                            Text(yearFormatted)
                                .foregroundStyle(.primary)
                                .font(.subheadline)
                        }
                        
                        // Number of seasons (for series only)
                        if displayShow.category == .series, let seasons = displayShow.numberOfSeasons, seasons > 0 {
                            HStack(spacing: 6) {
                                Image(systemName: "tv")
                                    .foregroundStyle(.secondary)
                                    .font(.subheadline)
                                    .frame(width: 20, alignment: .leading)
                                Text("\(seasons) \(seasons == 1 ? "season" : "seasons")")
                                    .foregroundStyle(.primary)
                                    .font(.subheadline)
                            }
                        }
                        
                        if !displayShow.watchProviders.isEmpty {
                            if displayShow.watchProviders.count == 1, let provider = displayShow.watchProviders.first {
                                // Single provider - display directly
                                HStack(spacing: 6) {
                                    if let logoURL = provider.logoURL {
                                        AsyncImageView(urlString: logoURL)
                                            .frame(width: 20, height: 20)
                                            .clipShape(RoundedRectangle(cornerRadius: 4))
                                    } else {
                                        // Empty space to align with other icons
                                        Color.clear
                                            .frame(width: 20)
                                    }
                                    Text(provider.name)
                                        .font(.subheadline)
                                        .foregroundStyle(.primary)
                                }
                            } else {
                                // Multiple providers - use dropdown
                                DisclosureGroup(isExpanded: $isProvidersExpanded) {
                                    VStack(alignment: .leading, spacing: 8) {
                                        ForEach(displayShow.watchProviders) { provider in
                                            HStack(spacing: 6) {
                                                if let logoURL = provider.logoURL {
                                                    AsyncImageView(urlString: logoURL)
                                                        .frame(width: 24, height: 24)
                                                        .clipShape(RoundedRectangle(cornerRadius: 4))
                                                }
                                                Text(provider.name)
                                                    .font(.subheadline)
                                                    .foregroundStyle(.primary)
                                            }
                                        }
                                    }
                                    .padding(.top, 4)
                                } label: {
                                    HStack(spacing: 6) {
                                        Image(systemName: "play.tv")
                                            .foregroundStyle(.secondary)
                                            .font(.subheadline)
                                            .frame(width: 20, alignment: .leading)
                                        Text("Where to watch")
                                            .font(.subheadline)
                                            .foregroundStyle(.primary)
                                        Text("(\(displayShow.watchProviders.count))")
                                            .font(.subheadline)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                .transaction { transaction in
                                    transaction.animation = nil
                                }
                            }
                        } else if !displayShow.streamingService.isEmpty && displayShow.streamingService != "Various" {
                            HStack(spacing: 6) {
                                Image(systemName: "play.tv")
                                    .foregroundStyle(.secondary)
                                    .font(.subheadline)
                                    .frame(width: 20, alignment: .leading)
                                Text(displayShow.streamingService)
                                    .foregroundStyle(.primary)
                                    .font(.subheadline)
                            }
                        }
                        
                        if let rating = displayShow.rating, rating > 0 {
                            HStack(spacing: 6) {
                                HStack(spacing: 4) {
                                    Text(String(format: "%.1f", rating))
                                        .foregroundStyle(.primary)
                                        .font(.subheadline.bold())
                                    Text("/ 10")
                                        .foregroundStyle(.secondary)
                                        .font(.caption) // Smaller to de-emphasize
                                }
                                Text("Audience Score")
                                    .foregroundStyle(.secondary)
                                    .font(.subheadline.bold())
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        
                        // Community average rating
                        if communityAverage > 0 {
                            VStack(alignment: .leading, spacing: 4) {
                                HStack(alignment: .firstTextBaseline, spacing: 6) {
                                    if let emoji = ratingEmoji(for: communityAverage) {
                                        Text(emoji)
                                            .font(.subheadline)
                                    }
                                    HStack(spacing: 4) {
                                        Text(String(format: "%.1f", displayedRating(for: communityAverage)))
                                            .foregroundStyle(.primary)
                                            .font(.subheadline.bold())
                                        Text("/ 10")
                                            .foregroundStyle(.secondary)
                                            .font(.caption) // Smaller to de-emphasize
                                    }
                                    Text("Neb Average")
                                        .foregroundStyle(.secondary)
                                        .font(.subheadline.bold())
                                        .fixedSize(horizontal: false, vertical: true)
                                    Text("(\(communityReviewCount))")
                                        .foregroundStyle(.secondary)
                                        .font(.subheadline)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                                .fixedSize(horizontal: false, vertical: true)
                                
                                // Discrepancy note if there's a significant difference
                                if let audienceRating = displayShow.rating, audienceRating > 0 {
                                    let nebRatingDisplay = displayedRating(for: communityAverage)
                                    let discrepancy = nebRatingDisplay - audienceRating
                                    
                                    if abs(discrepancy) >= 1.0 {
                                        HStack(spacing: 4) {
                                            Image(systemName: discrepancy > 0 ? "arrow.up" : "arrow.down")
                                                .font(.caption2)
                                                .foregroundStyle(discrepancy > 0 ? .green : .orange)
                                            
                                            Text(discrepancy > 0 
                                                ? "Rated higher by Neb reviewers" 
                                                : "Rated lower by Neb reviewers")
                                                .font(.caption)
                                                .foregroundStyle(discrepancy > 0 ? .green : .orange)
                                        }
                                    }
                                }
                            }
                        }
                        
                        // Add to list button - below Neb average
                        if !store.showLists.isEmpty {
                            addToListButton
                                .padding(.top, 8)
                        }
                    }
                }
            }
            
            // Synopsis
            Text(displayShow.synopsis)
                .font(.body)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
            
            // Genres
            if !displayShow.genres.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(displayShow.genres, id: \.self) { genre in
                            Text(genre)
                                .font(.caption)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Color.purple.opacity(0.2))
                                .foregroundStyle(.primary)
                                .clipShape(Capsule())
                        }
                    }
                }
            }
            
            // Attribution at bottom
            if displayShow.tmdbID != nil {
                VStack(alignment: .leading, spacing: 2) {
                    if !displayShow.watchProviders.isEmpty {
                        Text("Streaming data provided by JustWatch")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                    Text("Data provided by TMDB")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                .padding(.top, 4)
            }
        }
    }

    private var recommendationsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("You may also like...")
                .font(.title3.bold())
                .foregroundStyle(.primary)
            
            if store.isLoadingRecommendations {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding()
            } else if store.recommendations.isEmpty {
                ContentUnavailableView("No recommendations", systemImage: "sparkles", description: Text("Similar shows will appear here."))
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 16) {
                        ForEach(store.recommendations) { recommendedShow in
                            NavigationLink(value: recommendedShow) {
                                VStack(alignment: .leading, spacing: 8) {
                                    AsyncImageView(urlString: recommendedShow.posterURL)
                                        .frame(width: 120, height: 180)
                                        .clipShape(RoundedRectangle(cornerRadius: 12))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12)
                                                .stroke(Color(.separator), lineWidth: 1)
                                        )
                                    
                                    Text(recommendedShow.title)
                                        .font(.subheadline.bold())
                                        .foregroundStyle(.primary)
                                        .lineLimit(2)
                                        .frame(width: 120, alignment: .leading)
                                    
                                    Text(String(recommendedShow.year))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 4)
                }
            }
        }
    }
    
    @ViewBuilder
    private var reviewsSection: some View {
        
        let allReviews = reviews()
        let reviewPages = chunkReviews(allReviews, pageSize: 5)
        
        VStack(alignment: .leading, spacing: 4) {
            Spacer()
                .frame(height: 4)
            
            // Header with title and navigation arrows
            HStack {
                Text("Neb Reviews")
                    .font(.title3.bold())
                    .foregroundStyle(.primary)
                
                Spacer()
                
                // Navigation arrows for carousel
                if !allReviews.isEmpty && reviewPages.count > 1 {
                    // Previous page arrow
                    Button {
                        if currentReviewPage > 0 {
                            currentReviewPage -= 1
                        }
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.title3)
                            .foregroundStyle(currentReviewPage > 0 ? Color.primary : Color.gray.opacity(0.3))
                            .frame(width: 32, height: 32)
                    }
                    .disabled(currentReviewPage == 0)
                    .buttonStyle(.plain)
                    
                    // Spacing between buttons
                    Spacer()
                        .frame(width: 8)
                    
                    // Next page arrow
                    Button {
                        if currentReviewPage < reviewPages.count - 1 {
                            currentReviewPage += 1
                        }
                    } label: {
                        Image(systemName: "chevron.right")
                            .font(.title3)
                            .foregroundStyle(currentReviewPage < reviewPages.count - 1 ? Color.primary : Color.gray.opacity(0.3))
                            .frame(width: 32, height: 32)
                    }
                    .disabled(currentReviewPage >= reviewPages.count - 1)
                    .buttonStyle(.plain)
                }
            }
            
            // Season filter (only for series with multiple seasons)
            if displayShow.category == .series, let numberOfSeasons = displayShow.numberOfSeasons, numberOfSeasons > 0 {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Filter by Season")
                        .font(.subheadline.bold())
                        .foregroundStyle(.primary)
                    
                    HStack(spacing: 0) {
                        Picker("Filter by Season", selection: $filterSeason) {
                            Text("Entire Show").tag(nil as Int?)
                            ForEach(1...numberOfSeasons, id: \.self) { seasonNum in
                                Text("Season \(seasonNum)").tag(seasonNum as Int?)
                            }
                        }
                        .pickerStyle(.menu)
                        .foregroundStyle(.primary)
                        .padding(.leading, 0)
                        
                        Spacer()
                        
                        // Average season rating
                        if let avgRating = averageRatingForFilteredSeason, avgRating > 0 {
                            Text(String(format: "%.1f / 10", avgRating))
                                .font(.subheadline.bold())
                                .foregroundStyle(.primary)
                        }
                    }
                }
                .padding(.bottom, 16)
                .onChange(of: filterSeason) { oldValue, newValue in
                    // Reset to first page when filter changes
                    currentReviewPage = 0
                }
            }
            
            if allReviews.isEmpty {
                ContentUnavailableView("No reviews yet", systemImage: "bubble.left.and.exclamationmark", description: Text("Be the first to drop some nebs."))
            } else {
                VStack(spacing: 12) {
                    // TabView for smooth page transitions with full-width cards
                    TabView(selection: $currentReviewPage) {
                        ForEach(0..<reviewPages.count, id: \.self) { pageIndex in
                            HStack(spacing: 0) {
                                // Left spacing for gap between pages
                                Spacer()
                                    .frame(width: 8)
                                
                                // Content area with full-width cards
                                List {
                                    ForEach(reviewPages[pageIndex]) { review in
                                        let isOwnReview = store.currentUser?.username == review.author
                                        ReviewCard(
                                            review: review,
                                            showCategory: review.showCategory,
                                            isOwnReview: isOwnReview,
                                            onTap: {
                                                expandedReview = review
                                            }
                                        )
                                        .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
                                        .listRowBackground(Color.clear)
                                        .listRowSeparator(.hidden)
                                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                            if isOwnReview {
                                                Button {
                                                    store.deleteReview(review)
                                                } label: {
                                                    Label("Delete", systemImage: "trash")
                                                        .symbolRenderingMode(.hierarchical)
                                                }
                                                .tint(Color.red.opacity(0.7))
                                                
                                                Button {
                                                    reviewToEdit = review
                                                } label: {
                                                    Label("Edit", systemImage: "pencil.line")
                                                }
                                                .tint(Color.blue.opacity(0.7))
                                            }
                                        }
                                    }
                                }
                                .listStyle(.plain)
                                .scrollContentBackground(.hidden)
                                .scrollDisabled(true)
                                .environment(\.defaultMinListRowHeight, 0)
                                .frame(maxWidth: .infinity, alignment: .topLeading)
                                
                                // Right spacing for gap between pages
                                Spacer()
                                    .frame(width: 8)
                            }
                            .tag(pageIndex)
                        }
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                    .frame(height: calculateActualCarouselHeight(for: allReviews, reviewPages: reviewPages))
                    
                    // Page indicator
                    if reviewPages.count > 1 {
                        if reviewPages.count > 10 {
                            // Use number indicator for more than 50 reviews (10+ pages)
                            Text("\(currentReviewPage + 1) of \(reviewPages.count)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .padding(.top, 4)
                                .padding(.bottom, 16)
                        } else {
                            // Use dots for 10 or fewer pages
                            HStack(spacing: 6) {
                                ForEach(0..<reviewPages.count, id: \.self) { index in
                                    Circle()
                                        .fill(index == currentReviewPage ? Color.primary : Color.gray.opacity(0.3))
                                        .frame(width: 8, height: 8)
                                }
                            }
                            .padding(.top, 4)
                            .padding(.bottom, 16)
                        }
                    }
                }
            }
            
            Spacer()
                .frame(height: 4)
        }
        .sheet(item: $reviewToEdit) { review in
            EditReviewView(review: review)
                .environment(store)
        }
        .sheet(item: $expandedReview) { review in
            ExpandedReviewView(review: review)
        }
        .onChange(of: allReviews.count) { _, _ in
            // Reset to first page if reviews change
            if currentReviewPage > 0 && allReviews.isEmpty {
                currentReviewPage = 0
            }
        }
    }
    
    private func chunkReviews(_ reviews: [Review], pageSize: Int) -> [[Review]] {
        var chunks: [[Review]] = []
        for i in stride(from: 0, to: reviews.count, by: pageSize) {
            let chunk = Array(reviews[i..<min(i + pageSize, reviews.count)])
            chunks.append(chunk)
        }
        return chunks
    }
    
    private func calculateCarouselHeight(for reviews: [Review]) -> CGFloat {
        // Fixed height: 180pt per review card + 8pt spacing between cards
        let cardHeight: CGFloat = 200
        let spacing: CGFloat = 8
        let totalHeight = CGFloat(reviews.count) * cardHeight + CGFloat(max(0, reviews.count - 1)) * spacing
        return max(totalHeight, cardHeight)
    }
    
    private func calculateMaxCarouselHeight(for reviewPages: [[Review]]) -> CGFloat {
        // Fixed height: 220pt per review card + 8pt spacing between cards
        // listRowInsets add 8pt top/bottom padding per row (already included in spacing calculation)
        // Max 5 reviews per page
        let cardHeight: CGFloat = 220
        let spacing: CGFloat = 8  // This is the spacing between cards (8pt from listRowInsets bottom + 8pt from next row's top)
        let buffer: CGFloat = 48  // Extra buffer to prevent cutoff (increased from 32)
        let maxReviewsPerPage = 5
        // Calculate: (5 cards * 200) + (4 gaps * 8) + buffer = 1000 + 32 + 48 = 1080
        let totalHeight = CGFloat(maxReviewsPerPage) * cardHeight + CGFloat(maxReviewsPerPage - 1) * spacing + buffer
        return totalHeight
    }
    
    private func calculateActualCarouselHeight(for allReviews: [Review], reviewPages: [[Review]]) -> CGFloat {
        // Fixed height: 220pt per review card + 8pt spacing between cards
        // listRowInsets add 8pt top/bottom padding per row, creating 8pt gaps between cards
        // Add extra buffer to prevent cutoff
        let cardHeight: CGFloat = 220
        let spacing: CGFloat = 8
        let buffer: CGFloat = 48  // Extra buffer to prevent cutoff (increased from 32)
        
        // Calculate height for each page and use the maximum
        var maxPageHeight: CGFloat = 0
        for page in reviewPages {
            let reviewCount = page.count
            let pageHeight = CGFloat(reviewCount) * cardHeight + CGFloat(max(0, reviewCount - 1)) * spacing + buffer
            maxPageHeight = max(maxPageHeight, pageHeight)
        }
        return maxPageHeight
    }

    private var addToListButton: some View {
        // Get lists containing the show
        let listsContainingShow = store.showLists.filter { list in
            list.contains(show: displayShow)
        }
        let listsNotContainingShow = store.showLists.filter { list in
            !list.contains(show: displayShow)
        }
        let allListsContainingShow = listsContainingShow.count
        
        return HStack(spacing: 8) {
            Button {
                // Initialize selectedListIDs with current lists containing the show
                selectedListIDs = Set(listsContainingShow.map { $0.id })
                showingListPicker = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: allListsContainingShow > 0 
                          ? (listsContainingShow.first(where: { $0.isDefault }) != nil ? "bookmark.fill" : "list.bullet.rectangle")
                          : "plus.circle")
                        .foregroundStyle(.primary)
                        .font(.body)
                        .symbolRenderingMode(.hierarchical)
                        .frame(width: 20, height: 20)
                    
                    if allListsContainingShow > 0 {
                        if allListsContainingShow == 1, let list = listsContainingShow.first {
                            Text("In \"\(list.name)\"")
                                .font(.body)
                                .fontWeight(.medium)
                                .foregroundStyle(.primary)
                                .lineLimit(1)
                        } else {
                            Text("In \(allListsContainingShow) lists")
                                .font(.body)
                                .fontWeight(.medium)
                                .foregroundStyle(.primary)
                                .lineLimit(1)
                        }
                    } else {
                        Text("Add to List")
                            .font(.body)
                            .fontWeight(.medium)
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                    }
                }
                .contentShape(Rectangle())
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .sheet(isPresented: $showingListPicker) {
            listPickerSheet
        }
    }
    
    private var listPickerSheet: some View {
        NavigationStack {
            List {
                ForEach(store.showLists) { list in
                    Button {
                        if selectedListIDs.contains(list.id) {
                            selectedListIDs.remove(list.id)
                        } else {
                            selectedListIDs.insert(list.id)
                        }
                    } label: {
                        HStack {
                            Image(systemName: selectedListIDs.contains(list.id) ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(selectedListIDs.contains(list.id) ? .blue : .secondary)
                                .font(.title3)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(list.name)
                                    .font(.body)
                                    .foregroundStyle(.primary)
                                
                                if list.isDefault {
                                    Text("Default")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            
                            Spacer()
                            
                            Image(systemName: list.isDefault ? "bookmark.fill" : "list.bullet.rectangle")
                                .foregroundStyle(.secondary)
                                .font(.subheadline)
                        }
                        .contentShape(Rectangle())
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Add to Lists")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        showingListPicker = false
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        Task { @MainActor in
                            await updateShowLists()
                        }
                        showingListPicker = false
                    }
                }
            }
        }
    }
    
    private func updateShowLists() async {
        let currentListIDs = Set(store.showLists.filter { list in
            list.contains(show: displayShow)
        }.map { $0.id })
        
        // Find lists to add
        let listsToAdd = selectedListIDs.subtracting(currentListIDs)
        for listID in listsToAdd {
            await store.addShowToList(displayShow, listID: listID)
        }
        
        // Find lists to remove
        let listsToRemove = currentListIDs.subtracting(selectedListIDs)
        for listID in listsToRemove {
            await store.removeShowFromList(displayShow, listID: listID)
        }
    }
    
    private var addReviewSection: some View {
        // Use filterSeason to determine what season is being reviewed
        // For series, use filterSeason; for movies, always nil (entire show)
        let seasonToReview: Int? = displayShow.category == .series ? filterSeason : nil
        
        return VStack(alignment: .leading, spacing: 12) {
            // Check if user already has a review for the season being reviewed
            if userHasReviewForSeason(seasonToReview), let existingReview = userReviewForSeason(seasonToReview) {
                // User already has a review - show message to edit instead, but still allow changing season
                VStack(alignment: .leading, spacing: 12) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Drop Your Nebs")
                            .font(.title3.bold())
                            .foregroundStyle(.primary)
                        
                        // Show season selector (only for series)
                        if displayShow.category == .series, let numberOfSeasons = displayShow.numberOfSeasons, numberOfSeasons > 0 {
                            HStack(spacing: 8) {
                                Text("Reviewing:")
                                    .font(.subheadline)
                                    .foregroundStyle(.primary)
                                
                                Picker("Review Season", selection: $filterSeason) {
                                    Text("Entire Show").tag(nil as Int?)
                                    ForEach(1...numberOfSeasons, id: \.self) { seasonNum in
                                        Text("Season \(seasonNum)").tag(seasonNum as Int?)
                                    }
                                }
                                .pickerStyle(.menu)
                                .foregroundStyle(.primary)
                                .padding(.leading, 0)
                            }
                            .onChange(of: filterSeason) { oldValue, newValue in
                                // Reset to first page when filter changes
                                currentReviewPage = 0
                            }
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "info.circle")
                                .foregroundStyle(.secondary)
                            Text("You've already reviewed this")
                                .font(.headline)
                                .foregroundStyle(.primary)
                        }
                        
                        Text("Swipe left on your review below to edit or delete it.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        
                        Button(action: {
                            // Use the review from the currently filtered reviews if available
                            // This ensures we edit the correct season-specific review
                            if let reviewFromFilter = reviews().first(where: { $0.id == existingReview.id }) {
                                reviewToEdit = reviewFromFilter
                            } else {
                                reviewToEdit = existingReview
                            }
                        }) {
                            Label("Edit Your Review", systemImage: "pencil.line")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .tint(.purple)
                    }
                }
                .padding()
                .background(
                    colorScheme == .dark 
                        ? Color.purple.opacity(0.25)
                        : Color.purple.opacity(0.1),
                    in: RoundedRectangle(cornerRadius: 12)
                )
            } else {
                // User doesn't have a review - show the form
                VStack(alignment: .leading, spacing: 12) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Drop Your Nebs")
                            .font(.title3.bold())
                            .foregroundStyle(.primary)
                        
                        // Show what season is being reviewed (only for series)
                        if displayShow.category == .series, let numberOfSeasons = displayShow.numberOfSeasons, numberOfSeasons > 0 {
                            HStack(spacing: 8) {
                                Text("Reviewing:")
                                    .font(.subheadline)
                                    .foregroundStyle(.primary)
                                
                                Picker("Review Season", selection: $filterSeason) {
                                    Text("Entire Show").tag(nil as Int?)
                                    ForEach(1...numberOfSeasons, id: \.self) { seasonNum in
                                        Text("Season \(seasonNum)").tag(seasonNum as Int?)
                                    }
                                }
                                .pickerStyle(.menu)
                                .foregroundStyle(.primary)
                                .padding(.leading, 0)
                            }
                            .onChange(of: filterSeason) { oldValue, newValue in
                                // Reset to first page when filter changes
                                currentReviewPage = 0
                            }
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Rating")
                            .font(.subheadline.bold())
                            .foregroundStyle(.primary)
                        Slider(value: $newNebs, in: 0...10, step: 0.1)
                            .tint(.purple)
                        
                        HStack {
                            Button(action: {
                                newNebs = max(0, newNebs - 0.1)
                            }) {
                                Image(systemName: "minus.circle.fill")
                                    .font(.title2)
                                    .foregroundStyle(colorScheme == .dark ? Color.white : Color.black)
                                    .opacity(colorScheme == .dark ? 0.4 : 0.3)
                            }
                            .buttonStyle(.plain)
                            
                            Spacer()
                            
                            NebRatingView(rating: newNebs)
                            
                            Spacer()
                            
                            Button(action: {
                                newNebs = min(10, newNebs + 0.1)
                            }) {
                                Image(systemName: "plus.circle.fill")
                                    .font(.title2)
                                    .foregroundStyle(colorScheme == .dark ? Color.white : Color.black)
                                    .opacity(colorScheme == .dark ? 0.4 : 0.3)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        isCommentFocused = false
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Comment")
                            .font(.subheadline.bold())
                            .foregroundStyle(.primary)
                        TextEditor(text: $newComment)
                            .frame(minHeight: 120)
                            .scrollContentBackground(.hidden)
                            .background(Color(.systemBackground))
                            .foregroundColor(.primary)
                            .textSelection(.enabled)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(.separator), lineWidth: 1))
                            .contentMargins(4.0)
                            .focused($isCommentFocused)
                    }
                    
                    Button(action: addReview) {
                        Label("Post Review", systemImage: "paperplane.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.purple)
                    .disabled(!formIsValid)
                }
            }
        }
    }

    private var formIsValid: Bool {
        !newComment.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func addReview() {
        guard formIsValid else { return }
        let authorName = store.currentUser?.username ?? "Anonymous"
        // Use filterSeason to determine what season is being reviewed
        let seasonBeingReviewed: Int? = displayShow.category == .series ? filterSeason : nil
        
        // Ratings are stored directly on 0-10 scale
        // Use displayShow to ensure we use the show with the correct ID
        store.addReview(author: authorName,
                        comment: newComment.trimmingCharacters(in: .whitespacesAndNewlines),
                        rating: newNebs,
                        to: displayShow,
                        season: seasonBeingReviewed)
        newComment = ""
        newNebs = 5 // Reset to 5 out of 10
        // Filter stays the same (already set to the season being reviewed)
        
        // Dismiss keyboard
        isCommentFocused = false
    }
}


#Preview {
    let show = Show.previewData[0]
    let store = NebRatingsStore()
    
    return NavigationStack {
        ShowDetailView(show: show)
            .environment(store)
    }
}

#Preview("Without Poster") {
    let show = Show.previewData[4] // No poster show
    let store = NebRatingsStore()
    
    return NavigationStack {
        ShowDetailView(show: show)
            .environment(store)
    }
}

#Preview("With Many Reviews") {
    let show = Show.previewData[2] // The Dark Knight
    let store = NebRatingsStore()
    
    // Generate 20 reviews for this show
    let now = Date()
    let calendar = Calendar.current
    let showID = show.id
    let sampleAuthors = ["Alex", "Sarah", "Mike", "Emma", "Jordan", "Chris", "Taylor", "Riley", "Morgan", "Casey", "Drew", "Jamie", "Quinn", "Parker", "Sam", "Blake", "Cameron", "Avery", "Reese", "Dakota"]
    let sampleComments = [
        // Very short comments
        "Perfect!",
        "Amazing film.",
        "Loved it!",
        
        // Medium comments
        "Absolutely incredible! One of the best superhero movies ever made.",
        "Heath Ledger's performance as the Joker is legendary. Oscar-worthy!",
        "The action sequences are mind-blowing. The bank heist opening is perfect.",
        "Christopher Nolan's direction is masterful. Every scene is perfectly crafted.",
        "The Dark Knight elevates the superhero genre to new heights.",
        
        // Long comments
        "Intense, gripping, and emotionally powerful. A true masterpiece that redefined what superhero movies could be. The way Christopher Nolan weaves together complex themes of justice, morality, and chaos is nothing short of brilliant. Heath Ledger's Joker is not just a villain, but a force of nature that challenges everything Batman stands for. Every viewing reveals new layers and subtleties that I missed before.",
        "The cinematography is stunning. Gotham feels real and lived-in, creating an atmosphere that perfectly matches the dark tone of the story. Wally Pfister's work here is exemplary - the way he uses shadows and light to create tension is masterful. The practical effects, especially in the truck flip scene, are absolutely breathtaking. This is filmmaking at its finest.",
        "Aaron Eckhart as Two-Face is also fantastic. His transformation from Harvey Dent, the White Knight of Gotham, into the vengeful Two-Face is both heartbreaking and terrifying. The character arc is perfectly executed, showing how tragedy can corrupt even the most noble of souls. The makeup effects are incredible and add to the horror of the character.",
        "The moral complexity makes this more than just a comic book movie. It asks deep questions about what justice truly means, whether the ends justify the means, and how society can maintain order in the face of chaos. The film doesn't provide easy answers, instead forcing the audience to grapple with these difficult themes. This philosophical depth elevates it far above typical genre fare.",
        "The pacing is perfect. Despite its nearly three-hour runtime, the film never feels slow or bloated. Every scene serves a purpose, every line of dialogue matters. The tension builds relentlessly from the opening bank heist to the climactic confrontation with the Joker. It's a masterclass in narrative structure and pacing.",
        "One of those rare sequels that's better than the original. While Batman Begins was excellent, The Dark Knight takes everything that worked and amplifies it to perfection. The stakes are higher, the villains are more compelling, and the emotional impact is greater. This is how you make a sequel that surpasses its predecessor.",
        "The score by Hans Zimmer and James Newton Howard is incredible. The theme for the Joker, with its jarring, dissonant strings, perfectly captures the character's chaotic nature. The Batman theme builds on what was established in the first film, becoming more heroic and powerful. The music enhances every scene, creating an atmosphere that is both epic and intimate. It gives me chills every single time I hear it.",
        "This is what all superhero movies should strive to be. It proves that comic book adaptations can be serious, thought-provoking cinema while still delivering thrilling action and spectacle. The Dark Knight doesn't talk down to its audience or rely on shallow spectacle - it respects the intelligence of viewers and delivers a complex, emotionally resonant story.",
        "Rewatched it recently and it still holds up perfectly. More than a decade later, this film feels as fresh and impactful as it did on first viewing. The themes remain relevant, the performances are still astonishing, and the technical achievements continue to impress. It's a timeless work of art that will be studied and admired for generations to come.",
        "The practical effects make all the difference. There's no over-reliance on CGI here - real stunts, real explosions, real buildings being destroyed. This gives the action sequences weight and authenticity that many modern films lack. The truck flip scene, where an actual truck was flipped using a cable system, is one of the most impressive stunts ever filmed. It's the kind of practical filmmaking that makes you appreciate the craft.",
        "Christian Bale is the definitive Batman in my opinion. His portrayal captures both the tortured soul of Bruce Wayne and the calculated intensity of Batman. He brings gravitas and emotional depth to the role that few actors could match. The voice he uses for Batman might be a bit much for some, but it works perfectly in the context of the film - it's intimidating and distinct.",
        "The truck flip scene is one of the most impressive stunts ever filmed. The fact that they actually flipped a real truck using cables and explosives is mind-boggling. It's the kind of practical filmmaking that makes you appreciate the dedication and skill of the crew. The scene is perfectly shot and edited, creating a moment of pure cinematic spectacle that is both thrilling and awe-inspiring.",
        "Philosophically rich while still being entertaining. The film explores deep questions about justice, morality, and the nature of heroism without ever feeling pretentious or preachy. The Joker's philosophy of chaos versus Batman's belief in order creates a fascinating moral and philosophical debate that runs throughout the film. It's rare to find a blockbuster that can be this intellectually stimulating while still being thoroughly entertaining.",
        "The ending is perfect. Sets up the sequel beautifully while also providing a satisfying conclusion to this chapter of the story. Batman's decision to take the blame for Harvey Dent's crimes in order to preserve his legacy shows true heroism - he sacrifices his own reputation for the greater good. The final shot of Batman running from the police, with Commissioner Gordon's narration, is both haunting and inspiring."
    ]
    let ratings: [Double] = [5.0, 5.0, 5.0, 4.5, 5.0, 4.5, 5.0, 4.0, 5.0, 4.5, 5.0, 5.0, 4.0, 5.0, 4.5, 5.0, 4.5, 5.0, 4.5, 5.0]
    
    var reviews: [Review] = []
    for i in 0..<20 {
        let daysAgo = i
        let hoursAgo = i * 2
        reviews.append(Review(
            showID: showID,
            showTitle: show.title,
            showCategory: show.category,
            author: sampleAuthors[i],
            comment: sampleComments[i],
            nebRating: ratings[i],
            timestamp: calendar.date(byAdding: .hour, value: -hoursAgo, to: now) ?? now
        ))
    }
    
    // Sort by timestamp (newest first)
    store.reviews = reviews.sorted { $0.timestamp > $1.timestamp }
    
    return NavigationStack {
        ShowDetailView(show: show)
            .environment(store)
    }
}

#Preview("Long Text Reviews") {
    let store = NebRatingsStore()
    let show = Show(
        id: 999999,
        title: "Test Show - Long Reviews",
        category: .movie,
        year: 2024,
        synopsis: "A test show to demonstrate review text overflow handling.",
        tagline: "Testing overflow scenarios",
        streamingService: "Test Streaming"
    )
    
    // Create reviews with very long text
    let longText = """
    This is an extremely long review comment that should test how the review card handles text overflow. 
    The comment contains multiple sentences and paragraphs to ensure that the text truncation and ellipsis 
    work correctly. This review is intentionally verbose to push the boundaries of the UI design and ensure 
    that no matter how much text a user writes, the layout remains clean and readable. The review card should 
    properly handle this overflow scenario by truncating the text and showing an ellipsis when necessary.
    Additionally, this long text will help verify that the card height remains consistent and that there are 
    no layout issues when dealing with extensive user-generated content. We want to make sure that even with 
    very long reviews, the overall design maintains its aesthetic appeal and functionality.
    """
    
    var reviews: [Review] = []
    for i in 1...10 {
        reviews.append(Review(
            showID: show.id,
            showTitle: show.title,
            showCategory: show.category,
            author: "User\(i)",
            comment: i % 2 == 0 ? longText : "Short review.",
            nebRating: Double.random(in: 1.0...10.0),
            timestamp: Date().addingTimeInterval(TimeInterval(-i * 3600))
        ))
    }
    
    store.reviews = reviews
    
    return NavigationStack {
        ShowDetailView(show: show)
            .environment(store)
    }
}

#Preview("151 Reviews - Pagination Test") {
    let store = NebRatingsStore()
    let show = Show(
        id: 999998,
        title: "Test Show - 151 Reviews",
        category: .series,
        year: 2024,
        synopsis: "A test show with exactly 151 reviews to test pagination and the last page scenario.",
        tagline: "Testing pagination",
        streamingService: "Test Streaming",
        numberOfSeasons: 5
    )
    
    // Create exactly 151 reviews (30 pages of 5 = 150, plus 1 on page 31)
    var reviews: [Review] = []
    let authors = ["Alice", "Bob", "Charlie", "Diana", "Eve", "Frank", "Grace", "Henry", "Ivy", "Jack"]
    let comments = [
        "Great show! Really enjoyed it.",
        "Amazing performances from the cast.",
        "The plot was engaging throughout.",
        "Could have been better in places.",
        "Highly recommend watching this!",
        "Interesting concept but execution was lacking.",
        "One of the best shows I've seen this year.",
        "The writing could have been tighter.",
        "Fantastic cinematography and direction.",
        "Worth watching for the character development alone."
    ]
    
    for i in 1...151 {
        reviews.append(Review(
            showID: show.id,
            showTitle: show.title,
            showCategory: show.category,
            author: authors[i % authors.count] + "\(i)",
            comment: comments[i % comments.count],
            nebRating: Double.random(in: 1.0...10.0),
            timestamp: Date().addingTimeInterval(TimeInterval(-i * 3600))
        ))
    }
    
    store.reviews = reviews
    
    return NavigationStack {
        ShowDetailView(show: show)
            .environment(store)
    }
}

