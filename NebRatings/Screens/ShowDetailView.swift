//
//  ShowDetailView.swift
//  NebRatings
//
//  Created by Cole Whaley on 11/29/25.
//

import SwiftUI

struct ShowDetailView: View {
    @Environment(NebRatingsStore.self) private var store: NebRatingsStore
    let show: Show

    @State private var newAuthor = ""
    @State private var newComment = ""
    @State private var newNebs: Double = 3
    @State private var showReviews: [Review] = []
    
    init(show: Show) {
        self.show = show
    }

    private var reviews: [Review] {
        showReviews
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header
                Divider()
                reviewsSection
                Divider()
                addReviewSection
            }
            .padding()
            .navigationTitle(show.title)
            .navigationBarTitleDisplayMode(.inline)
        }
        .background(Color(.systemGroupedBackground))
        .task {
            await loadShowReviews()
        }
    }
    
    private func loadShowReviews() async {
        await store.queryReviews(showID: show.id)
        showReviews = store.reviews(for: show)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(show.tagline)
                .font(.title2.bold())
            Text(show.synopsis)
                .font(.body)
                .foregroundStyle(.secondary)
            HStack {
                Label("\(show.year)", systemImage: "calendar")
                Label(show.streamingService, systemImage: "play.tv")
            }
            .font(.callout)
            .foregroundStyle(.secondary)
        }
    }

    private var reviewsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Neb Reviews")
                .font(.title3.bold())
            if reviews.isEmpty {
                ContentUnavailableView("No reviews yet", systemImage: "bubble.left.and.exclamationmark", description: Text("Be the first to drop some nebs."))
            } else {
                VStack(spacing: 16) {
                    ForEach(reviews) { review in
                        ReviewCard(review: review)
                    }
                }
            }
        }
    }

    private var addReviewSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Drop Your Nebs")
                .font(.title3.bold())
            TextField("Author name", text: $newAuthor)
                .textFieldStyle(.roundedBorder)
            VStack(alignment: .leading) {
                Text("Rating")
                    .font(.subheadline.bold())
                NebRatingView(rating: newNebs)
                Slider(value: $newNebs, in: 0...5, step: 0.5)
                    .tint(.purple)
            }
            VStack(alignment: .leading) {
                Text("Comment")
                    .font(.subheadline.bold())
                TextEditor(text: $newComment)
                    .frame(minHeight: 120)
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.gray.opacity(0.3)))
            }
            Button(action: addReview) {
                Label("Post Review", systemImage: "paperplane.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(!formIsValid)
        }
    }

    private var formIsValid: Bool {
        !newAuthor.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !newComment.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func addReview() {
        guard formIsValid else { return }
        store.addReview(author: newAuthor.trimmingCharacters(in: .whitespacesAndNewlines),
                        comment: newComment.trimmingCharacters(in: .whitespacesAndNewlines),
                        rating: newNebs,
                        to: show)
        newAuthor = ""
        newComment = ""
        newNebs = 3
        
        // Refresh reviews for this show
        Task {
            await loadShowReviews()
        }
    }
}

