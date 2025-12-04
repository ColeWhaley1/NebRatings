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

    @State private var newComment = ""
    @State private var newNebs: Double = 3
    @State private var detailedShow: Show?
    
    init(show: Show) {
        self.show = show
    }
    
    private var displayShow: Show {
        detailedShow ?? show
    }

    private var reviews: [Review] {
        store.reviews(for: show)
    }
    
    private var yearFormatted: String {
        return "\(displayShow.year)"
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
        .scrollContentBackground(.hidden)
        .background(Color(.systemGroupedBackground))
        .navigationTitle(displayShow.title)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadShowDetails()
            await loadShowReviews()
            await loadRecommendations()
        }
    }
    
    private func loadShowDetails() async {
        // Fetch full details if we have a TMDB ID and don't already have genres
        if let tmdbID = show.tmdbID, show.genres.isEmpty {
            if let detailed = await store.fetchShowDetailsByTMDBID(tmdbID: tmdbID, category: show.category) {
                detailedShow = detailed
            }
        }
    }
    
    private func loadShowReviews() async {
        await store.queryReviews(showID: show.id)
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
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 6) {
                            Image(systemName: "calendar")
                                .foregroundStyle(.secondary)
                                .font(.subheadline)
                            Text(yearFormatted)
                                .foregroundStyle(.primary)
                                .font(.subheadline)
                        }
                        if !displayShow.streamingService.isEmpty && displayShow.streamingService != "Various" {
                            HStack(spacing: 6) {
                                Image(systemName: "play.tv")
                                    .foregroundStyle(.secondary)
                                    .font(.subheadline)
                                Text(displayShow.streamingService)
                                    .foregroundStyle(.primary)
                                    .font(.subheadline)
                            }
                        }
                        if let rating = displayShow.rating, rating > 0 {
                            HStack(spacing: 6) {
                                Image(systemName: "star.fill")
                                    .foregroundStyle(.yellow)
                                    .font(.subheadline)
                                Text(String(format: "%.1f", rating))
                                    .foregroundStyle(.primary)
                                    .font(.subheadline)
                            }
                        }
                    }
                    
                    if displayShow.averageNebs > 0 {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 8) {
                                NebRatingView(rating: displayShow.averageNebs)
                                Text("\(displayShow.reviews.count) reviews")
                                    .font(.subheadline)
                                    .foregroundStyle(.primary)
                            }
                        }
                        .padding(.top, 4)
                    }
                }
                .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
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
            
            // TMDB source attribution at bottom
            if displayShow.tmdbID != nil {
                Text("Data provided by TMDB")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
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
    
    private var reviewsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Neb Reviews")
                .font(.title3.bold())
                .foregroundStyle(.primary)
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
                .foregroundStyle(.primary)
            VStack(alignment: .leading, spacing: 12) {
                Text("Rating")
                    .font(.subheadline.bold())
                    .foregroundStyle(.primary)
                NebRatingView(rating: newNebs)
                Slider(value: $newNebs, in: 0...5, step: 0.5)
                    .tint(.purple)
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
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(.separator), lineWidth: 1))
                    .contentMargins(4.0)
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
        !newComment.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func addReview() {
        guard formIsValid else { return }
        let authorName = store.currentUser?.name ?? "Anonymous"
        store.addReview(author: authorName,
                        comment: newComment.trimmingCharacters(in: .whitespacesAndNewlines),
                        rating: newNebs,
                        to: displayShow)
        newComment = ""
        newNebs = 3
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

