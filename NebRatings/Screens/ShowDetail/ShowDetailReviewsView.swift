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
    
    var body: some View {
        let allReviews = prioritizedReviews(reviews())
        let pageCount = ReviewPagination.pageCount(for: allReviews.count, pageSize: 5)

        VStack(alignment: .leading, spacing: 4) {
            Spacer()
                .frame(height: 4)

            HStack {
                Text("Neb Reviews")
                    .font(.title3.bold())
                    .foregroundStyle(.primary)

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
            }
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

    /// Orders reviews: your own first, then friends', then everyone else — each tier by recency.
    private func prioritizedReviews(_ reviews: [Review]) -> [Review] {
        reviews.sorted { lhs, rhs in
            let lr = priorityRank(lhs)
            let rr = priorityRank(rhs)
            if lr != rr { return lr < rr }
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
