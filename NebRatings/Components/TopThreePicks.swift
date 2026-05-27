//
//  TopThreePicks.swift
//  NebRatings
//

import SwiftUI

struct TopThreePicks: View {
    @Environment(NebRatingsStore.self) private var store: NebRatingsStore

    let reviews: [Review]
    /// Called when a pick is tapped — receives the resolved Show.
    let onSelect: (Show) -> Void

    private static let medals = ["🥇", "🥈", "🥉"]

    /// Top 3 by nebRating, tiebreaker = most recent. If multiple reviews exist for the
    /// same show (e.g. season-level), the highest-rated review for that show is used.
    private var picks: [Review] {
        var bestPerShow: [Int: Review] = [:]
        for review in reviews {
            if let existing = bestPerShow[review.showID] {
                if review.nebRating > existing.nebRating ||
                    (review.nebRating == existing.nebRating && review.timestamp > existing.timestamp) {
                    bestPerShow[review.showID] = review
                }
            } else {
                bestPerShow[review.showID] = review
            }
        }
        return bestPerShow.values
            .sorted { lhs, rhs in
                if lhs.nebRating != rhs.nebRating { return lhs.nebRating > rhs.nebRating }
                return lhs.timestamp > rhs.timestamp
            }
            .prefix(3)
            .map { $0 }
    }

    var body: some View {
        // Hide entirely if user has fewer than 3 distinct shows
        if picks.count >= 3 {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 6) {
                    Image(systemName: "trophy.fill")
                        .foregroundStyle(.yellow)
                    Text("Top 3 Picks")
                        .font(.subheadline.bold())
                        .foregroundStyle(.secondary)
                }
                HStack(alignment: .top, spacing: 12) {
                    ForEach(Array(picks.enumerated()), id: \.element.id) { index, review in
                        pickCard(review: review, rank: index)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func pickCard(review: Review, rank: Int) -> some View {
        let show = store.show(for: review)
        Button {
            if let show { onSelect(show) }
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                ZStack(alignment: .topLeading) {
                    Group {
                        if let posterURL = show?.posterURL {
                            AsyncImageView(urlString: posterURL)
                                .aspectRatio(2/3, contentMode: .fill)
                        } else {
                            ZStack {
                                Rectangle().fill(Color.gray.opacity(0.2))
                                Image(systemName: review.showCategory == .movie ? "film" : "tv")
                                    .font(.title)
                                    .foregroundStyle(.secondary)
                            }
                            .aspectRatio(2/3, contentMode: .fill)
                        }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 10))

                    Text(Self.medals[rank])
                        .font(.title2)
                        .padding(6)
                        .background(.ultraThinMaterial, in: Circle())
                        .padding(4)
                }

                Text(review.showTitle)
                    .font(.caption.bold())
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                HStack(spacing: 3) {
                    Text(String(format: "%.1f", review.nebRating))
                        .font(.caption2.bold())
                    Text("/ 10")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.plain)
    }
}
