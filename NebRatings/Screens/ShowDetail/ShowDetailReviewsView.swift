//
//  ShowDetailReviewsView.swift
//  NebRatings
//
//  Reviews section for ShowDetailView with pagination and season filter.
//

import SwiftUI

struct ShowDetailReviewsView: View {
    @Environment(NebRatingsStore.self) private var store: NebRatingsStore
    let displayShow: Show
    let reviews: () -> [Review]
    @Binding var filterSeason: Int?
    @Binding var currentReviewPage: Int
    @Binding var reviewToEdit: Review?
    @Binding var expandedReview: Review?
    let averageRatingForFilteredSeason: Double?

    /// Sort *order* only — captured on page load and refreshed when the
    /// set of reviews changes. We deliberately don't cache the full `Review`
    /// structs here: reactions are stored *inside* each `Review`, and a
    /// cached value-type array would freeze them. Instead `body` resolves
    /// each id against the live store on every render — order stays put
    /// (no shuffling on reaction-count change), but reaction pills update
    /// in real time.
    @State private var sortedReviewIDs: [UUID] = []

    /// Set when the user taps a review author's avatar/name — pushes that
    /// user's profile onto whichever NavigationStack this detail view lives
    /// in. Item-driven (not path-driven) because this view doesn't own a
    /// navigation path.
    @State private var profileDestination: UserProfileDestination?

    /// Shown after reporting a review, so the action gives clear feedback.
    @State private var showReportedNotice = false

    var body: some View {
        let liveByID: [UUID: Review] = Dictionary(
            uniqueKeysWithValues: reviews().map { ($0.id, $0) }
        )
        let allReviews = sortedReviewIDs.compactMap { liveByID[$0] }
        let pageCount = ReviewPagination.pageCount(for: allReviews.count, pageSize: 5)

        VStack(alignment: .leading, spacing: 4) {
            Spacer()
                .frame(height: 4)

            HStack(spacing: 8) {
                Text("Neb Reviews")
                    .font(.title3.bold())
                    .foregroundStyle(.primary)

                if !allReviews.isEmpty {
                    ReviewCountBadge(count: allReviews.count)
                }

                Spacer()

                ReviewPagerChevrons(pageCount: pageCount, currentPage: $currentReviewPage)
            }

            if displayShow.category == .series, let numberOfSeasons = displayShow.numberOfSeasons, numberOfSeasons > 0 {
                seasonFilterRow(numberOfSeasons: numberOfSeasons)
            }

            if allReviews.isEmpty {
                ContentUnavailableView("No reviews yet", systemImage: "bubble.left.and.exclamationmark", description: Text("Be the first to drop some nebs."))
            } else {
                PaginatedReviewsCarousel(
                    reviews: allReviews,
                    pageSize: 5,
                    currentPage: $currentReviewPage,
                    style: .swipeable
                ) { review in
                    reviewCard(for: review)
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
        .navigationDestination(item: $profileDestination) { dest in
            UserProfileView(userID: dest.userID, initialProfile: dest.profile)
        }
        .alert("Review reported", isPresented: $showReportedNotice) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Thanks — this review is now hidden from you and sent to our moderation team, who will review it and take action on any violation.")
        }
        .task {
            // Initial sort when the view appears.
            sortedReviewIDs = prioritizedReviews(reviews()).map(\.id)
        }
        .onChange(of: reviews().map(\.id)) { _, _ in
            // Re-sort only when the *set* of reviews changes (add/delete).
            // Reaction-count changes don't change the IDs, so they don't
            // trigger this — reviews stay put while you're reading them.
            sortedReviewIDs = prioritizedReviews(reviews()).map(\.id)
        }
        .onChange(of: filterSeason) { _, _ in
            // Season filter changes the visible set — re-sort.
            sortedReviewIDs = prioritizedReviews(reviews()).map(\.id)
        }
    }

    // MARK: - Subviews

    @ViewBuilder
    private func seasonFilterRow(numberOfSeasons: Int) -> some View {
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

                Spacer()

                if let avgRating = averageRatingForFilteredSeason, avgRating > 0 {
                    Text(String(format: "%.1f / 10", avgRating))
                        .font(.subheadline.bold())
                        .foregroundStyle(.primary)
                }
            }
        }
        .padding(.bottom, 16)
        .onChange(of: filterSeason) { _, _ in
            currentReviewPage = 0
        }
    }

    @ViewBuilder
    private func reviewCard(for review: Review) -> some View {
        // A blocked author's review is shown blurred (name + text unreadable)
        // with an unblock affordance, everywhere it would appear (Guideline 1.2).
        if store.isBlocked(review.authorID) {
            BlockedReviewCard(review: review)
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    if let authorID = review.authorID {
                        Button {
                            store.unblockUser(userID: authorID)
                        } label: {
                            Label("Unblock", systemImage: "hand.raised.slash")
                        }
                        .tint(.purple)
                    }
                }
        } else {
            interactiveReviewCard(review)
        }
    }

    @ViewBuilder
    private func interactiveReviewCard(_ review: Review) -> some View {
        let isOwnReview = store.currentUser?.username == review.author
        let authorProfile = store.cachedProfile(for: review.authorID)
        ReviewCard(
            review: review,
            showCategory: review.showCategory,
            isOwnReview: isOwnReview,
            authorAvatarEmoji: authorProfile?.avatarEmoji,
            isFriend: store.isFriend(review.authorID),
            onTap: {
                expandedReview = review
            },
            currentUserID: store.currentUser?.id,
            onReact: { emoji in
                Task { await store.setReaction(emoji: emoji, on: review) }
            },
            // Own review → jump to the Profile tab. Otherwise push the author's
            // profile. Legacy reviews without an authorID get no handler.
            onAuthorTap: isOwnReview
                ? { store.selectedTab = .profile }
                : review.authorID.map { authorID in
                    { profileDestination = UserProfileDestination(userID: authorID, profile: authorProfile) }
                }
        )
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            if isOwnReview {
                Button(role: .destructive) {
                    store.deleteReview(review)
                } label: {
                    Label("Delete", systemImage: "trash")
                }

                Button {
                    reviewToEdit = review
                } label: {
                    Label("Edit", systemImage: "pencil")
                }
                .tint(.blue)
            } else {
                // Moderation on others' reviews (Guideline 1.2). Labeled so the
                // action is obvious; both give clear feedback (report shows a
                // confirmation, block blurs their card).
                Button {
                    store.reportReview(review)
                    showReportedNotice = true
                } label: {
                    Label("Report", systemImage: "flag")
                }
                .tint(.orange)

                if let authorID = review.authorID {
                    Button(role: .destructive) {
                        store.blockUser(userID: authorID, username: review.author)
                    } label: {
                        Label("Block", systemImage: "hand.raised")
                    }
                }
            }
        }
    }

    /// Orders reviews: your own first, then friends', then everyone else.
    /// Within each tier: most-reacted first, then most-recent first.
    private func prioritizedReviews(_ reviews: [Review]) -> [Review] {
        reviews.sorted { lhs, rhs in
            let lr = priorityRank(lhs)
            let rr = priorityRank(rhs)
            if lr != rr { return lr < rr }
            let lc = lhs.totalReactionCount
            let rc = rhs.totalReactionCount
            if lc != rc { return lc > rc }
            return lhs.timestamp > rhs.timestamp
        }
    }

    /// 0 = your review, 1 = a friend's, 2 = everyone else.
    private func priorityRank(_ review: Review) -> Int {
        if review.authorID == store.currentUser?.id || review.author == store.currentUser?.username {
            return 0
        }
        if store.isFriend(review.authorID) {
            return 1
        }
        return 2
    }
}
