//
//  ShowPosterRow.swift
//  NebRatings
//
//  Horizontal poster strip used by the Discover tab's curated sections.
//  Each poster is a NavigationLink(value: Show) — the hosting stack must
//  register a Show destination. Renders nothing when `shows` is empty, so
//  callers can compose sections without their own emptiness checks.
//

import SwiftUI

struct ShowPosterRow: View {
    let title: String
    var subtitle: String? = nil
    let shows: [Show]
    /// Optional badge per show id, drawn on the poster's top-trailing corner
    /// (e.g. "9.2" for rankings or "12 reviews" for volume).
    var badges: [Int: String] = [:]

    private let posterWidth: CGFloat = 110
    private var posterHeight: CGFloat { posterWidth * 3 / 2 }

    var body: some View {
        if !shows.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.title3.bold())
                        .foregroundStyle(.primary)
                    if let subtitle {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal, 16)

                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(alignment: .top, spacing: 12) {
                        ForEach(shows) { show in
                            NavigationLink(value: show) {
                                posterCard(for: show)
                            }
                            // Squishy press feedback — cards feel tactile.
                            .buttonStyle(PressableButtonStyle(pressedScale: 0.95))
                        }
                    }
                    .padding(.horizontal, 16)
                }
            }
        }
    }

    private func posterCard(for show: Show) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            ZStack(alignment: .topTrailing) {
                Group {
                    if let posterURL = show.posterURL {
                        AsyncImageView(urlString: posterURL)
                    } else {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.gray.opacity(0.2))
                            .overlay(
                                Image(systemName: show.category == .movie ? "film" : "tv")
                                    .font(.title2)
                                    .foregroundStyle(.secondary)
                            )
                    }
                }
                .frame(width: posterWidth, height: posterHeight)
                .clipShape(RoundedRectangle(cornerRadius: 10))

                if let badge = badges[show.id] {
                    Text(badge)
                        .font(.caption2.bold())
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Color.purple.opacity(0.9), in: Capsule())
                        .padding(5)
                }
            }

            Text(show.title)
                .font(.caption)
                .foregroundStyle(.primary)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
                // Reserve two lines so cards align regardless of title length.
                .frame(width: posterWidth, height: 30, alignment: .topLeading)
        }
    }
}

#Preview {
    NavigationStack {
        ScrollView {
            ShowPosterRow(
                title: "Trending This Week",
                shows: Show.previewData,
                badges: [Show.previewData[0].id: "9.2"]
            )
        }
    }
}
