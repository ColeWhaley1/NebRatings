//
//  ExpandedReviewView.swift
//  NebRatings
//
//  Created by Cole Whaley on 11/29/25.
//

import SwiftUI

struct ExpandedReviewView: View {
    let reviewID: UUID
    @Environment(\.dismiss) private var dismiss
    @Environment(NebRatingsStore.self) private var store
    @State private var showingEditReview = false
    
    // Get the latest review from the store to ensure it's always up-to-date
    private var currentReview: Review? {
        store.reviews.first { $0.id == reviewID } ?? store.userReviews.first { $0.id == reviewID }
    }
    
    private var isOwnReview: Bool {
        store.userReviews.contains { $0.id == reviewID }
    }
    
    // Convenience initializer that takes a Review for backward compatibility
    init(review: Review) {
        self.reviewID = review.id
    }
    
    var body: some View {
        NavigationStack {
            if let review = currentReview {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        // Header
                        //
                        // Layout (all left-aligned, top-to-bottom):
                        //   1. Avatar (top-left) + Rating (top-right, where
                        //      it's always lived)
                        //   2. Author name (full width, can wrap)
                        //   3. Friend badge (only when applicable)
                        //   4. Show title (full width, can wrap)
                        //   5. Timestamp
                        //
                        // Putting the username below the avatar gives a long
                        // name the full sheet width — never crowds the rating.
                        VStack(alignment: .leading, spacing: 12) {
                            let authorProfile = store.cachedProfile(for: review.authorID)

                            // Row 1 — avatar pinned left, rating pinned right.
                            HStack(alignment: .top) {
                                AvatarView(emoji: authorProfile?.avatarEmoji, size: 56)
                                Spacer(minLength: 12)
                                NebRatingView(rating: review.nebRating)
                                    .fixedSize()
                            }

                            // Row 2 — author name, full width, left-aligned.
                            Text(review.author)
                                .font(.title2.bold())
                                .foregroundStyle(.primary)
                                .lineLimit(2)
                                .multilineTextAlignment(.leading)
                                .frame(maxWidth: .infinity, alignment: .leading)

                            // Row 3 — friend badge (own line).
                            if !isOwnReview && store.isFriend(review.authorID) {
                                Text("Friend")
                                    .font(.caption.bold())
                                    .foregroundStyle(.teal)
                                    .lineLimit(1)
                                    .fixedSize(horizontal: true, vertical: false)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(Color.teal.opacity(0.18), in: Capsule())
                            }

                            // Row 4 — show title.
                            Text(review.showTitle)
                                .font(.headline)
                                .foregroundStyle(.secondary)
                                .lineLimit(3)
                                .multilineTextAlignment(.leading)
                                .frame(maxWidth: .infinity, alignment: .leading)

                            // Row 5 — timestamp.
                            Text(review.timestamp.formatted(date: .complete, time: .shortened))
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.bottom, 8)
                        
                        Divider()
                        
                        // Full comment
                        Text(review.comment)
                            .font(.body)
                            .foregroundStyle(.primary)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding()
                }
                .navigationTitle("Review")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        if isOwnReview {
                            Button {
                                showingEditReview = true
                            } label: {
                                Image(systemName: "pencil")
                                    .foregroundStyle(.primary)
                            }
                        }
                    }
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Done") {
                            dismiss()
                        }
                    }
                }
                .sheet(isPresented: $showingEditReview) {
                    if let review = currentReview {
                        EditReviewView(review: review)
                            .environment(store)
                    }
                }
            } else {
                ContentUnavailableView(
                    "Review not found",
                    systemImage: "exclamationmark.triangle",
                    description: Text("This review may have been deleted.")
                )
                .navigationTitle("Review")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Done") {
                            dismiss()
                        }
                    }
                }
            }
        }
    }
}

