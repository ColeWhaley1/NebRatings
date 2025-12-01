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
    
    init(show: Show) {
        self.show = show
    }

    private var reviews: [Review] {
        store.reviews(for: show)
    }
    
    private var yearFormatted: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .none
        formatter.usesGroupingSeparator = false
        return formatter.string(from: NSNumber(value: show.year)) ?? "\(show.year)"
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // Backdrop image - only show if backdrop exists
                if let backdropURL = show.backdropURL, !backdropURL.isEmpty {
                    AsyncImageView(urlString: backdropURL)
                        .frame(height: 250)
                        .frame(maxWidth: .infinity)
                        .clipped()
                        .overlay(
                            LinearGradient(
                                colors: [.clear, Color(.systemGroupedBackground).opacity(0.8)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
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
        .navigationTitle(show.title)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadShowReviews()
        }
    }
    
    private func loadShowReviews() async {
        await store.queryReviews(showID: show.id)
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 16) {
            // Poster - only show if poster exists
            if show.posterURL != nil {
                AsyncImageView(urlString: show.posterURL)
                    .frame(width: 120, height: 180)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(
                                LinearGradient(
                                    colors: [Color.purple.opacity(0.4), Color.blue.opacity(0.3)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 2
                            )
                    )
                    .shadow(color: .purple.opacity(0.3), radius: 12, x: 0, y: 6)
            }
            
            // Details
            VStack(alignment: .leading, spacing: 12) {
                Text(show.synopsis)
                    .font(.system(size: 16, weight: .regular, design: .default))
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
                
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 4) {
                        Image(systemName: "calendar")
                            .foregroundStyle(.secondary)
                        Text(yearFormatted)
                            .foregroundStyle(.primary)
                    }
                    HStack(spacing: 4) {
                        Image(systemName: "info.circle")
                            .foregroundStyle(.secondary)
                            .font(.caption)
                        Text(show.streamingService)
                            .foregroundStyle(.secondary)
                            .font(.caption)
                    }
                }
                .font(.body)
                
                if show.averageNebs > 0 {
                    HStack(spacing: 8) {
                        NebRatingView(rating: show.averageNebs)
                        Text("\(show.reviews.count) reviews")
                            .font(.subheadline)
                            .foregroundStyle(.primary)
                    }
                }
            }
            .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
        }
    }

    private var reviewsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Neb Reviews")
                .font(.system(size: 24, weight: .bold, design: .default))
                .foregroundStyle(.primary)
            if reviews.isEmpty {
                ContentUnavailableView("No reviews yet", systemImage: "bubble.left.and.exclamationmark", description: Text("Be the first to drop some nebs."))
                    .padding(.top, 8)
            } else {
                VStack(spacing: 16) {
                    ForEach(reviews) { review in
                        ReviewCard(review: review)
                            .transition(.asymmetric(
                                insertion: .move(edge: .trailing).combined(with: .opacity),
                                removal: .opacity
                            ))
                    }
                }
                .animation(.spring(response: 0.5, dampingFraction: 0.8), value: reviews.count)
            }
        }
    }

    private var addReviewSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Drop Your Nebs")
                .font(.system(size: 24, weight: .bold, design: .default))
                .foregroundStyle(.primary)
            VStack(alignment: .leading, spacing: 12) {
                Text("Rating")
                    .font(.subheadline.bold())
                    .foregroundStyle(.primary)
                NebRatingView(rating: newNebs)
                Slider(value: $newNebs, in: 0...5, step: 0.5)
                    .tint(
                        LinearGradient(
                            colors: [Color.purple, Color.blue],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
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
                    .font(.headline)
            }
            .buttonStyle(.borderedProminent)
            .tint(.purple)
            .controlSize(.large)
            .shadow(color: .purple.opacity(0.3), radius: 8, x: 0, y: 4)
            .disabled(!formIsValid)
            .scaleEffect(formIsValid ? 1.0 : 0.98)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: formIsValid)
        }
    }

    private var formIsValid: Bool {
        !newComment.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func addReview() {
        guard formIsValid else { return }
        let authorName = store.currentUser?.displayName ?? "Anonymous"
        store.addReview(author: authorName,
                        comment: newComment.trimmingCharacters(in: .whitespacesAndNewlines),
                        rating: newNebs,
                        to: show)
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

