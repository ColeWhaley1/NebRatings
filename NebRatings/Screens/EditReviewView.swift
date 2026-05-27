//
//  EditReviewView.swift
//  NebRatings
//
//  Created by Cole Whaley on 11/29/25.
//

import SwiftUI

struct EditReviewView: View {
    let review: Review
    @Environment(NebRatingsStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var comment: String
    @State private var rating: Double
    /// nil = entire show; otherwise a specific season.
    @State private var selectedSeason: Int?
    @FocusState private var isCommentFocused: Bool
    @Environment(\.colorScheme) private var colorScheme

    init(review: Review) {
        self.review = review
        _comment = State(initialValue: review.comment)
        _rating = State(initialValue: review.nebRating)
        _selectedSeason = State(initialValue: review.season)
    }

    private var resolvedShow: Show? { store.show(for: review) }

    private var numberOfSeasons: Int? {
        guard review.showCategory == .series else { return nil }
        return resolvedShow?.numberOfSeasons
    }

    private var formIsValid: Bool {
        !comment.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var ratingEmoji: String? {
        if rating >= 8.0 { return "🔥" }
        if rating <= 4.0 { return "🤮" }
        return nil
    }

    private var ratingTint: Color {
        if rating >= 8.0 { return .green }
        if rating <= 4.0 { return .red }
        if rating >= 6.5 { return .blue }
        return .purple
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    showHeader
                    ratingCard
                    if let seasons = numberOfSeasons, seasons > 0 {
                        scopeCard(seasons: seasons)
                    }
                    commentCard
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 32)
            }
            .background(Color(.systemGroupedBackground))
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("Edit Review")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { saveReview() }
                        .fontWeight(.semibold)
                        .disabled(!formIsValid)
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { isCommentFocused = false }
                        .fontWeight(.semibold)
                }
            }
        }
    }

    // MARK: - Sections

    private var showHeader: some View {
        HStack(spacing: 12) {
            Group {
                if let posterURL = resolvedShow?.posterURL {
                    AsyncImageView(urlString: posterURL)
                        .aspectRatio(2/3, contentMode: .fill)
                        .frame(width: 50, height: 75)
                } else {
                    ZStack {
                        Rectangle().fill(Color.gray.opacity(0.2))
                        Image(systemName: review.showCategory == .movie ? "film" : "tv")
                            .foregroundStyle(.secondary)
                    }
                    .frame(width: 50, height: 75)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 6) {
                Text(review.showCategory.rawValue.uppercased())
                    .font(.caption2.bold())
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(review.showCategory.badgeColor.opacity(0.15), in: Capsule())
                    .foregroundStyle(review.showCategory.badgeColor)

                Text(review.showTitle)
                    .font(.headline)
                    .lineLimit(2)
            }
            Spacer()
        }
        .padding(14)
        .background(card)
    }

    private var ratingCard: some View {
        VStack(spacing: 16) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                if let emoji = ratingEmoji {
                    Text(emoji).font(.system(size: 28))
                }
                Text(String(format: "%.1f", rating))
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .foregroundStyle(ratingTint)
                    .contentTransition(.numericText(value: rating))
                Text("/ 10")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }

            Slider(value: $rating, in: 0...10, step: 0.1)
                .tint(ratingTint)

            HStack(spacing: 12) {
                stepButton(systemName: "minus") {
                    rating = max(0, (rating * 10).rounded() / 10 - 0.1)
                }
                Spacer()
                Text("Drag the slider or tap ± to fine-tune")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                stepButton(systemName: "plus") {
                    rating = min(10, (rating * 10).rounded() / 10 + 0.1)
                }
            }
        }
        .padding(16)
        .background(card)
    }

    private func scopeCard(seasons: Int) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Reviewing")
                    .font(.subheadline.bold())
                Spacer()
                Text(scopeLabel)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    scopeChip(label: "Entire show", isSelected: selectedSeason == nil) {
                        selectedSeason = nil
                    }
                    ForEach(1...seasons, id: \.self) { season in
                        scopeChip(label: "Season \(season)", isSelected: selectedSeason == season) {
                            selectedSeason = season
                        }
                    }
                }
                .padding(.horizontal, 2)
            }
        }
        .padding(16)
        .background(card)
    }

    private var commentCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Your Review")
                    .font(.subheadline.bold())
                Spacer()
                Text("\(comment.count) chars")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }

            ZStack(alignment: .topLeading) {
                if comment.isEmpty {
                    Text("Share what you thought…")
                        .foregroundStyle(.tertiary)
                        .padding(.top, 10)
                        .padding(.leading, 6)
                }
                TextEditor(text: $comment)
                    .focused($isCommentFocused)
                    .frame(minHeight: 140)
                    .scrollContentBackground(.hidden)
            }
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isCommentFocused ? Color.purple : Color.primary.opacity(0.1),
                            lineWidth: isCommentFocused ? 1.5 : 1)
            )
        }
        .padding(16)
        .background(card)
    }

    // MARK: - Pieces

    private var card: some View {
        RoundedRectangle(cornerRadius: 16)
            .fill(Color(.secondarySystemGroupedBackground))
    }

    private var scopeLabel: String {
        if let s = selectedSeason { return "Season \(s)" }
        return "Entire show"
    }

    private func scopeChip(label: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.subheadline.weight(isSelected ? .semibold : .regular))
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(
                    Capsule().fill(isSelected ? Color.purple : Color.gray.opacity(0.18))
                )
                .foregroundStyle(isSelected ? .white : .primary)
        }
        .buttonStyle(.plain)
    }

    private func stepButton(systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 32, height: 32)
                .background(Color.purple, in: Circle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Save

    private func saveReview() {
        guard formIsValid else { return }
        store.updateReview(review, comment: comment, rating: rating, newSeason: selectedSeason)
        dismiss()
    }
}

#Preview {
    let review = Review.sampleData[0]
    let store = NebRatingsStore()
    return EditReviewView(review: review)
        .environment(store)
}
