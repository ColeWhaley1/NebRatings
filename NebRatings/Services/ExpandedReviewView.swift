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
    /// Pushes the author's profile inside this sheet's own NavigationStack.
    @State private var profileDestination: UserProfileDestination?
    /// Native share sheet payload (text + poster when available).
    @State private var sharePayload: SharePayload?
    @State private var isPreparingShare = false
    
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
                            let authorTap = authorTapAction(for: review, profile: authorProfile)

                            // Row 1 — avatar pinned left, rating pinned right.
                            HStack(alignment: .top) {
                                if let authorTap {
                                    Button(action: authorTap) {
                                        AvatarView(emoji: authorProfile?.avatarEmoji, size: 56)
                                    }
                                    .buttonStyle(.plain)
                                } else {
                                    AvatarView(emoji: authorProfile?.avatarEmoji, size: 56)
                                }
                                Spacer(minLength: 12)
                                NebRatingView(rating: review.nebRating)
                                    .fixedSize()
                            }

                            // Row 2 — author name, full width, left-aligned.
                            // Tappable together with the avatar: routes to the
                            // author's profile (or the Profile tab for your own).
                            if let authorTap {
                                Button(action: authorTap) {
                                    Text(review.author)
                                        .font(.title2.bold())
                                        .foregroundStyle(.primary)
                                        .lineLimit(2)
                                        .multilineTextAlignment(.leading)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel("View \(review.author)'s profile")
                            } else {
                                Text(review.author)
                                    .font(.title2.bold())
                                    .foregroundStyle(.primary)
                                    .lineLimit(2)
                                    .multilineTextAlignment(.leading)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }

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
                    ToolbarItemGroup(placement: .navigationBarLeading) {
                        if isOwnReview {
                            Button {
                                showingEditReview = true
                            } label: {
                                Image(systemName: "pencil")
                                    .foregroundStyle(.primary)
                            }
                        }
                        if isPreparingShare {
                            ProgressView()
                        } else {
                            Button {
                                Task { await prepareShare(for: review) }
                            } label: {
                                Image(systemName: "square.and.arrow.up")
                                    .foregroundStyle(.primary)
                            }
                            .accessibilityLabel("Share review")
                        }
                    }
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Done") {
                            dismiss()
                        }
                    }
                }
                .sheet(item: $sharePayload) { payload in
                    ActivityShareSheet(items: payload.items)
                }
                .sheet(isPresented: $showingEditReview) {
                    if let review = currentReview {
                        EditReviewView(review: review)
                            .environment(store)
                    }
                }
                .navigationDestination(item: $profileDestination) { dest in
                    UserProfileView(userID: dest.userID, initialProfile: dest.profile)
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

    /// Builds the share payload via the shared ShareService (enticing copy +
    /// nebratings.com link + poster) and presents the system share sheet.
    private func prepareShare(for review: Review) async {
        isPreparingShare = true
        let show = store.show(for: review)
        let items = await ShareService.items(for: .review(review, show: show))
        isPreparingShare = false
        sharePayload = SharePayload(items: items)
    }

    /// Routing for a tap on the author's avatar/name. Own review → close the
    /// sheet and switch to the Profile tab. Someone else (with an authorID) →
    /// push their profile inside this sheet's stack. Legacy reviews without an
    /// authorID return nil so the identity isn't a dead button.
    private func authorTapAction(for review: Review, profile: UserProfile?) -> (() -> Void)? {
        if isOwnReview {
            return {
                dismiss()
                store.selectedTab = .profile
            }
        }
        return review.authorID.map { authorID in
            { profileDestination = UserProfileDestination(userID: authorID, profile: profile) }
        }
    }
}

