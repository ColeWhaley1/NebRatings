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
        let reviewPages = ShowDetailHelpers.chunkReviews(allReviews, pageSize: 5)
        
        VStack(alignment: .leading, spacing: 4) {
            Spacer()
                .frame(height: 4)
            
            HStack {
                Text("Neb Reviews")
                    .font(.title3.bold())
                    .foregroundStyle(.primary)
                
                Spacer()
                
                if !allReviews.isEmpty && reviewPages.count > 1 {
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
                    
                    Spacer()
                        .frame(width: 8)
                    
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
            
            if allReviews.isEmpty {
                ContentUnavailableView("No reviews yet", systemImage: "bubble.left.and.exclamationmark", description: Text("Be the first to drop some nebs."))
            } else {
                VStack(spacing: 12) {
                    TabView(selection: $currentReviewPage) {
                        ForEach(0..<reviewPages.count, id: \.self) { pageIndex in
                            HStack(spacing: 0) {
                                Spacer()
                                    .frame(width: 8)
                                
                                List {
                                    ForEach(reviewPages[pageIndex]) { review in
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
                                        .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
                                        .listRowBackground(Color.clear)
                                        .listRowSeparator(.hidden)
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
                                .listStyle(.plain)
                                .scrollContentBackground(.hidden)
                                .scrollDisabled(true)
                                .environment(\.defaultMinListRowHeight, 0)
                                .frame(maxWidth: .infinity, alignment: .topLeading)
                                
                                Spacer()
                                    .frame(width: 8)
                            }
                            .tag(pageIndex)
                        }
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                    .frame(height: ShowDetailHelpers.calculateActualCarouselHeight(for: allReviews, reviewPages: reviewPages))
                    
                    if reviewPages.count > 1 {
                        if reviewPages.count > 10 {
                            Text("\(currentReviewPage + 1) of \(reviewPages.count)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .padding(.top, 4)
                                .padding(.bottom, 16)
                        } else {
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
            if currentReviewPage > 0 && allReviews.isEmpty {
                currentReviewPage = 0
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
