//
//  ShowDetailView.swift
//  NebRatings
//
//  Main show detail screen. Composes header, reviews, add review, and recommendations.
//

import SwiftUI

struct ShowDetailView: View {
    @Environment(NebRatingsStore.self) private var store: NebRatingsStore
    @Environment(\.dismiss) private var dismiss
    let show: Show
    var initialSeasonFilter: Int? = nil

    @State private var newComment = ""
    @State private var newNebs: Double = 5
    @State private var detailedShow: Show?
    @State private var isProvidersExpanded = false
    @FocusState private var isCommentFocused: Bool
    @State private var reviewToEdit: Review?
    @State private var currentReviewPage = 0
    @State private var expandedReview: Review?
    @State private var showingListPicker = false
    @State private var selectedListID: String?
    /// List ID -> seasons (nil = entire show). For series only; movies always nil.
    @State private var listSeasonSelections: [String: [Int]?] = [:]
    @State private var draftListSelections: [String: [Int]?] = [:]
    @State private var selectedSeason: Int? = nil
    @State private var filterSeason: Int? = nil
    /// YouTube trailers from TMDB. Empty = section hidden entirely.
    @State private var trailers: [Trailer] = []
    /// Native share sheet payload (text + poster when available).
    @State private var shareItems: [Any] = []
    @State private var isSharePresented = false
    @State private var isPreparingShare = false
    
    private var displayShow: Show {
        detailedShow ?? show
    }

    private func reviews() -> [Review] {
        let showID = displayShow.id
        var filtered = store.reviews.filter { $0.showID == showID }
        
        if let filterSeason = filterSeason {
            filtered = filtered.filter { $0.season == filterSeason }
        } else {
            filtered = filtered.filter { $0.season == nil }
        }
        
        let currentUserName = store.currentUser?.username
        return filtered.sorted { review1, review2 in
            let isReview1Own = review1.author == currentUserName
            let isReview2Own = review2.author == currentUserName
            if isReview1Own && !isReview2Own { return true }
            if !isReview1Own && isReview2Own { return false }
            return review1.timestamp > review2.timestamp
        }
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
    
    private var yearFormatted: String {
        "\(displayShow.year)"
    }
    
    private var communityAverage: Double {
        let showID = displayShow.id
        let entireShowReviews = store.reviews.filter { $0.showID == showID && $0.season == nil }
        guard !entireShowReviews.isEmpty else { return 0 }
        return entireShowReviews.reduce(0.0) { $0 + $1.nebRating } / Double(entireShowReviews.count)
    }
    
    private var communityReviewCount: Int {
        let showID = displayShow.id
        return store.reviews.filter { $0.showID == showID && $0.season == nil }.count
    }
    
    private var averageRatingForFilteredSeason: Double? {
        let showID = displayShow.id
        var filteredReviews = store.reviews.filter { $0.showID == showID }
        if let filterSeason = filterSeason {
            filteredReviews = filteredReviews.filter { $0.season == filterSeason }
        } else {
            filteredReviews = filteredReviews.filter { $0.season == nil }
        }
        guard !filteredReviews.isEmpty else { return nil }
        return filteredReviews.reduce(0.0) { $0 + $1.nebRating } / Double(filteredReviews.count)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
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
                        ShowDetailHeaderView(
                            displayShow: displayShow,
                            isProvidersExpanded: $isProvidersExpanded,
                            communityAverage: communityAverage,
                            communityReviewCount: communityReviewCount,
                            yearFormatted: yearFormatted,
                            addToListButton: AnyView(
                                ShowDetailAddToListButton(
                                    displayShow: displayShow,
                                    draftListSelections: $draftListSelections,
                                    showingListPicker: $showingListPicker
                                )
                            )
                        )
                        Divider()
                            .background(Color(.separator))
                        if !trailers.isEmpty {
                            ShowDetailTrailersView(trailers: trailers)
                            Divider()
                                .background(Color(.separator))
                        }
                        ShowDetailReviewsView(
                            displayShow: displayShow,
                            reviews: reviews,
                            filterSeason: $filterSeason,
                            currentReviewPage: $currentReviewPage,
                            reviewToEdit: $reviewToEdit,
                            expandedReview: $expandedReview,
                            averageRatingForFilteredSeason: averageRatingForFilteredSeason
                        )
                        Divider()
                            .background(Color(.separator))
                        ShowDetailAddReviewView(
                            displayShow: displayShow,
                            reviews: reviews,
                            filterSeason: $filterSeason,
                            newComment: $newComment,
                            newNebs: $newNebs,
                            isCommentFocused: $isCommentFocused,
                            currentReviewPage: $currentReviewPage,
                            reviewToEdit: $reviewToEdit,
                            userHasReviewForSeason: userHasReviewForSeason,
                            userReviewForSeason: userReviewForSeason,
                            onAddReview: addReview
                        )
                        Divider()
                            .background(Color(.separator))
                        ShowDetailRecommendationsView()
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
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if isPreparingShare {
                    ProgressView()
                } else {
                    Button {
                        Task { await prepareShare() }
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                            .foregroundStyle(.primary)
                    }
                    .accessibilityLabel("Share \(displayShow.title)")
                }
            }
        }
        .sheet(isPresented: $isSharePresented) {
            ActivityShareSheet(items: shareItems)
        }
        .task {
            if let season = initialSeasonFilter {
                filterSeason = season
                selectedSeason = season
            }
            // Fire concurrently with the detail/review loads below — the id and
            // category never change between `show` and `detailedShow`, so this
            // doesn't need to wait for details.
            async let trailersFetch = store.fetchTrailers(for: show)
            await loadShowDetails()
            await loadShowReviews()
            await loadRecommendations()
            await store.loadUserLists()
            syncListSelectionsFromStore()
            if selectedListID == nil {
                selectedListID = store.showLists.first(where: { $0.isDefault })?.id ?? store.showLists.first?.id
            }
            trailers = await trailersFetch
        }
        .onChange(of: store.showLists) { _, _ in
            if selectedListID != nil && !store.showLists.contains(where: { $0.id == selectedListID }) {
                selectedListID = store.showLists.first(where: { $0.isDefault })?.id ?? store.showLists.first?.id
            } else if selectedListID == nil && !store.showLists.isEmpty {
                selectedListID = store.showLists.first(where: { $0.isDefault })?.id ?? store.showLists.first?.id
            }
            if !showingListPicker {
                syncListSelectionsFromStore()
            }
        }
        .onAppear {
            Task { await store.loadUserLists() }
        }
        .sheet(isPresented: $showingListPicker) {
            ShowDetailListPickerSheet(
                displayShow: displayShow,
                showingListPicker: $showingListPicker,
                initialSelections: draftListSelections,
                onDone: { finalSelections in
                    listSeasonSelections = finalSelections
                    await updateShowLists(selections: finalSelections)
                }
            )
        }
    }
    
    private func loadShowDetails() async {
        let needsDetails = show.genres.isEmpty
            || (show.category == .series && show.numberOfSeasons == nil)
        if needsDetails {
            if let detailed = await store.fetchShowDetailsByTMDBID(tmdbID: show.id, category: show.category) {
                detailedShow = detailed
                await loadShowReviews()
                await loadRecommendations()
            }
        }
    }
    
    private func loadShowReviews() async {
        await store.queryReviews(showID: displayShow.id)
    }
    
    private func loadRecommendations() async {
        await store.loadRecommendations(for: displayShow)
    }
    
    private func syncListSelectionsFromStore() {
        var newSelections: [String: [Int]?] = [:]
        for list in store.showLists.filter({ $0.contains(show: displayShow) }) {
            let ref = list.showReferences.first(where: {
                $0.id == displayShow.id && $0.category == displayShow.category
            }) ?? list.showReferences.first(where: { $0.id == displayShow.id })
            if let ref = ref {
                newSelections[list.id] = ref.seasons
            }
        }
        listSeasonSelections = newSelections
        draftListSelections = newSelections
    }
    
    private func updateShowLists(selections: [String: [Int]?]? = nil) async {
        let sel = selections ?? listSeasonSelections
        let currentListIDs = Set(store.showLists.filter { list in
            list.contains(show: displayShow)
        }.map { $0.id })
        
        for (listID, seasons) in sel {
            await store.addShowToList(displayShow, listID: listID, seasons: seasons)
        }
        
        for listID in currentListIDs.subtracting(Set(sel.keys)) {
            await store.removeShowFromList(displayShow, listID: listID)
        }
    }
    
    /// Builds the share payload: the show, my rating + review for the current
    /// season filter when I have one, and the poster when fetchable.
    private func prepareShare() async {
        isPreparingShare = true
        let myReview = userReviewForSeason(displayShow.category == .series ? filterSeason : nil)
        var items: [Any] = [ShareContentBuilder.text(for: displayShow, myReview: myReview)]
        if let poster = await ShareContentBuilder.posterImage(from: displayShow.posterURL) {
            items.append(poster)
        }
        shareItems = items
        isPreparingShare = false
        isSharePresented = true
    }

    private func addReview() {
        guard !newComment.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        let authorName = store.currentUser?.username ?? "Anonymous"
        let seasonBeingReviewed: Int? = displayShow.category == .series ? filterSeason : nil
        
        store.addReview(author: authorName,
                        comment: newComment.trimmingCharacters(in: .whitespacesAndNewlines),
                        rating: newNebs,
                        to: displayShow,
                        season: seasonBeingReviewed)
        newComment = ""
        newNebs = 5
        isCommentFocused = false
    }
}

// MARK: - Previews

#Preview {
    let show = Show.previewData[0]
    let store = NebRatingsStore()
    
    return NavigationStack {
        ShowDetailView(show: show)
            .environment(store)
    }
}

#Preview("Without Poster") {
    let show = Show.previewData[4]
    let store = NebRatingsStore()
    
    return NavigationStack {
        ShowDetailView(show: show)
            .environment(store)
    }
}

#Preview("With Many Reviews") {
    let show = Show.previewData[2]
    let store = NebRatingsStore()
    
    let now = Date()
    let calendar = Calendar.current
    let showID = show.id
    let sampleAuthors = ["Alex", "Sarah", "Mike", "Emma", "Jordan", "Chris", "Taylor", "Riley", "Morgan", "Casey", "Drew", "Jamie", "Quinn", "Parker", "Sam", "Blake", "Cameron", "Avery", "Reese", "Dakota"]
    let sampleComments = [
        "Perfect!", "Amazing film.", "Loved it!",
        "Absolutely incredible! One of the best superhero movies ever made.",
        "Heath Ledger's performance as the Joker is legendary. Oscar-worthy!",
        "The action sequences are mind-blowing. The bank heist opening is perfect.",
        "Christopher Nolan's direction is masterful. Every scene is perfectly crafted.",
        "The Dark Knight elevates the superhero genre to new heights.",
        "Intense, gripping, and emotionally powerful. A true masterpiece.",
        "The cinematography is stunning. Gotham feels real and lived-in.",
        "Aaron Eckhart as Two-Face is also fantastic.",
        "The moral complexity makes this more than just a comic book movie.",
        "The pacing is perfect. Despite its nearly three-hour runtime.",
        "One of those rare sequels that's better than the original.",
        "The score by Hans Zimmer and James Newton Howard is incredible.",
        "This is what all superhero movies should strive to be.",
        "Rewatched it recently and it still holds up perfectly.",
        "The practical effects make all the difference.",
        "Christian Bale is the definitive Batman in my opinion.",
        "The truck flip scene is one of the most impressive stunts ever filmed.",
        "Philosophically rich while still being entertaining.",
        "The ending is perfect. Sets up the sequel beautifully."
    ]
    let ratings: [Double] = [5.0, 5.0, 5.0, 4.5, 5.0, 4.5, 5.0, 4.0, 5.0, 4.5, 5.0, 5.0, 4.0, 5.0, 4.5, 5.0, 4.5, 5.0, 4.5, 5.0]
    
    var reviews: [Review] = []
    for i in 0..<20 {
        reviews.append(Review(
            showID: showID,
            showTitle: show.title,
            showCategory: show.category,
            author: sampleAuthors[i],
            comment: sampleComments[i],
            nebRating: ratings[i],
            timestamp: calendar.date(byAdding: .hour, value: -i * 2, to: now) ?? now
        ))
    }
    
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
    
    let longText = """
    This is an extremely long review comment that should test how the review card handles text overflow.
    The comment contains multiple sentences and paragraphs to ensure that the text truncation and ellipsis
    work correctly. This review is intentionally verbose to push the boundaries of the UI design.
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
        synopsis: "A test show with exactly 151 reviews to test pagination.",
        tagline: "Testing pagination",
        streamingService: "Test Streaming",
        numberOfSeasons: 5
    )
    
    var reviews: [Review] = []
    let authors = ["Alice", "Bob", "Charlie", "Diana", "Eve", "Frank", "Grace", "Henry", "Ivy", "Jack"]
    let comments = [
        "Great show!", "Amazing performances.", "The plot was engaging.",
        "Could have been better.", "Highly recommend!", "Interesting concept.",
        "One of the best shows.", "The writing could have been tighter.",
        "Fantastic cinematography.", "Worth watching."
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
