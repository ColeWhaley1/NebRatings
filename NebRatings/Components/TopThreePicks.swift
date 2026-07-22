//
//  TopThreePicks.swift
//  NebRatings
//

import SwiftUI

struct TopThreePicks: View {
    @Environment(NebRatingsStore.self) private var store: NebRatingsStore

    let reviews: [Review]
    /// Called when the user taps a pick. The parent decides how to navigate
    /// (push onto a `NavigationPath`, set a `navigationDestination(item:)`
    /// binding, etc.). Using an explicit closure here — instead of an inner
    /// `NavigationLink` — avoids the SwiftUI tap-bleed bug where multiple
    /// side-by-side `NavigationLink`s inside a `List` row all fire on tap.
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
        // store.show(for:) always resolves at least a minimal Show.
        let show = store.show(for: review)
        if let show {
            Button {
                onSelect(show)
            } label: {
                pickCardLabel(review: review, rank: rank, show: show)
                    .contentShape(Rectangle())
            }
            // `.plain` preserves each Text's own foreground style (so the
            // title/rating stay primary instead of being tinted blue by
            // the accent color, which `.borderless` would apply). The
            // multi-fire tap bug we fixed was specific to NavigationLink;
            // Button + explicit closure isolates each tap on its own.
            .buttonStyle(.plain)
        } else {
            pickCardLabel(review: review, rank: rank, show: nil)
        }
    }

    @ViewBuilder
    private func pickCardLabel(review: Review, rank: Int, show: Show?) -> some View {
        VStack(alignment: .leading, spacing: 6) {
                ZStack(alignment: .topLeading) {
                    Group {
                        if let posterURL = show?.posterURL {
                            AsyncImageView(urlString: posterURL)
                                // `.fit` (not `.fill`): with no bounding frame, this
                                // poster's height must derive from the column width.
                                // `.fill` in an unbounded-height ScrollView makes the
                                // box grow to contain the proposal and overflow the
                                // column, clipping the poster. The art still fills the
                                // box edge-to-edge — AsyncImageView fills + clips.
                                .aspectRatio(2/3, contentMode: .fit)
                        } else {
                            ZStack {
                                Rectangle().fill(Color.gray.opacity(0.2))
                                Image(systemName: review.showCategory == .movie ? "film" : "tv")
                                    .font(.title)
                                    .foregroundStyle(.secondary)
                            }
                            .aspectRatio(2/3, contentMode: .fit)
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
                    .font(.subheadline.bold())
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                HStack(alignment: .firstTextBaseline, spacing: 3) {
                    Text(String(format: "%.1f", review.nebRating))
                        .font(.title3.bold())
                        .foregroundStyle(.primary)
                    Text("/ 10")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}
