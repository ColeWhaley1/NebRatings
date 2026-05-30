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
                        VStack(alignment: .leading, spacing: 12) {
                            // Author and rating
                            HStack(alignment: .top, spacing: 12) {
                                let authorProfile = store.cachedProfile(for: review.authorID)
                                AvatarView(emoji: authorProfile?.avatarEmoji, size: 44)

                                VStack(alignment: .leading, spacing: 4) {
                                    HStack(spacing: 6) {
                                        Text(review.author)
                                            .font(.title2.bold())
                                            .foregroundStyle(.primary)
                                        if !isOwnReview && store.isFriend(review.authorID) {
                                            Text("Friend")
                                                .font(.caption.bold())
                                                .foregroundStyle(.teal)
                                                .padding(.horizontal, 6)
                                                .padding(.vertical, 2)
                                                .background(Color.teal.opacity(0.18), in: Capsule())
                                        }
                                    }

                                    Text(review.showTitle)
                                        .font(.headline)
                                        .foregroundStyle(.secondary)
                                }

                                Spacer()

                                NebRatingView(rating: review.nebRating)
                            }
                            
                            // Timestamp
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

