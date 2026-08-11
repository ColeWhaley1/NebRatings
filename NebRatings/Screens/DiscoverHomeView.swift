//
//  DiscoverHomeView.swift
//  NebRatings
//
//  The Discover tab's browse experience (shown when the search field is
//  empty): mood chips plus curated sections — TMDB-driven rows (trending,
//  popular, hidden gems, …), personalized rows (favorite genres, "because
//  you rated"), and NebRatings community rankings. Sections load in
//  parallel and simply don't render when their fetch comes back empty.
//

import SwiftUI
import UIKit  // mood-chip tap haptic

struct DiscoverHomeView: View {
    @Environment(NebRatingsStore.self) private var store

    /// The Discover payload lives in the store (warmed during splash), so the
    /// view is a thin renderer — no on-appear fetch waterfall.
    private var feed: NebRatingsStore.DiscoverFeed { store.discoverFeed }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                moodsSection

                if !feed.seasonal.isEmpty {
                    seasonalSection
                }

                if !feed.isLoaded {
                    HStack {
                        Spacer()
                        ProgressView("Curating…")
                        Spacer()
                    }
                    .padding(.vertical, 40)
                } else {
                    ShowPosterRow(title: "Trending This Week", shows: feed.trendingWeek)

                    rankedRow(
                        title: "Highest Rated in the Past Month",
                        subtitle: "Rated by the NebRatings community",
                        ranked: feed.highestRatedMonth,
                        badge: { String(format: "🔥 %.1f", $0.averageRating) }
                    )

                    rankedRow(
                        title: "Most Reviewed in the Past Month",
                        subtitle: "What the community is talking about",
                        ranked: feed.mostReviewedMonth,
                        badge: { "\($0.reviewCount) \($0.reviewCount == 1 ? "review" : "reviews")" }
                    )

                    if let becauseYouRatedTitle = feed.becauseYouRatedTitle {
                        ShowPosterRow(
                            title: "Because You Rated \(becauseYouRatedTitle) Highly",
                            shows: feed.becauseYouRatedShows
                        )
                    }

                    ShowPosterRow(
                        title: "Based on Your Favorite Genres",
                        subtitle: favoriteGenresSubtitle,
                        shows: feed.favoriteGenreShows
                    )

                    rankedRow(
                        title: "Highest Rated This Year",
                        subtitle: "The community's \(Calendar.current.component(.year, from: Date())) favorites",
                        ranked: feed.highestRatedYear,
                        badge: { String(format: "🔥 %.1f", $0.averageRating) }
                    )

                    ShowPosterRow(title: "Recently Released", shows: feed.recentlyReleased)
                    ShowPosterRow(title: "Popular Movies", subtitle: "What everyone's watching", shows: feed.popularMovies)
                    ShowPosterRow(title: "Popular TV Shows", subtitle: "Trending series right now", shows: feed.popularTV)
                    ShowPosterRow(title: "Comedies", subtitle: "Laugh-out-loud picks", shows: feed.comedies)
                    ShowPosterRow(title: "Action & Adventure", subtitle: "Edge-of-your-seat thrills", shows: feed.actionAdventure)
                    ShowPosterRow(title: "Award Winners", subtitle: "All-time critical darlings", shows: feed.awardWinners)
                }
            }
            .padding(.vertical, 12)
        }
        .task {
            // Usually a no-op — the splash preload already warmed this. Only
            // fetches if the user reached Discover before it finished.
            await store.preloadDiscover()
        }
        .refreshable {
            await store.preloadDiscover(force: true)
        }
        .onChange(of: store.contentPreference) { _, _ in
            // Changing the maturity level invalidates every curated row.
            Task { await store.preloadDiscover(force: true) }
        }
    }

    // MARK: - Moods

    /// Staggers the chips' pop-in the first time the section appears.
    @State private var moodsAppeared = false

    /// Each mood gets its own gradient so the strip reads as a colorful,
    /// inviting deck instead of a wall of identical chips.
    private static let moodGradients: [String: [Color]] = [
        "feel-good": [.yellow, .orange],
        "mind-bending": [.purple, .indigo],
        "cozy-night": [.orange, .pink],
        "date-night": [.pink, .red],
        "family-movie": [.green, .mint],
        "hidden-gems": [.teal, .cyan],
        "scary": [.red, .black],
        "emotional": [.blue, .indigo],
        "fast-paced": [.orange, .red],
        "epic-adventure": [.green, .teal],
        "crime": [.gray, .black],
        "mystery": [.indigo, .blue],
        "sci-fi": [.cyan, .blue],
        "fantasy": [.purple, .pink],
        "weekend-binge": [.red, .orange],
        "comfort-show": [.mint, .green]
    ]

    private func moodColors(_ mood: Mood) -> [Color] {
        Self.moodGradients[mood.id] ?? [.purple, .indigo]
    }

    private var moodsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("What are you in the mood for?")
                .font(.title3.bold())
                .padding(.horizontal, 16)

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHGrid(rows: [GridItem(.fixed(44)), GridItem(.fixed(44))], spacing: 10) {
                    ForEach(Array(MoodCatalog.all.enumerated()), id: \.element.id) { index, mood in
                        NavigationLink(value: mood) {
                            HStack(spacing: 7) {
                                Text(mood.emoji)
                                    .font(.title3)
                                Text(mood.name)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.white)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.85)
                                    .shadow(color: .black.opacity(0.25), radius: 1, y: 1)
                                Spacer(minLength: 0)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            // Uniform width with the emoji/name pinned left, so
                            // the two rows read as a tidy aligned grid instead of
                            // ragged content-sized pills.
                            .frame(width: 176, alignment: .leading)
                            .background(
                                LinearGradient(
                                    colors: moodColors(mood).map { $0.opacity(0.85) },
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                in: Capsule()
                            )
                            .shadow(color: moodColors(mood)[0].opacity(0.35), radius: 5, y: 3)
                        }
                        // Squishy press-down, then a light tick as the mood opens.
                        .buttonStyle(PressableButtonStyle())
                        .simultaneousGesture(TapGesture().onEnded {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        })
                        // Staggered pop-in on first appearance — the deck
                        // "deals" itself in left to right.
                        .opacity(moodsAppeared ? 1 : 0)
                        .scaleEffect(moodsAppeared ? 1 : 0.6)
                        .animation(
                            .spring(response: 0.4, dampingFraction: 0.65).delay(Double(index) * 0.035),
                            value: moodsAppeared
                        )
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 4) // room for the chip shadows
            }
        }
        .onAppear { moodsAppeared = true }
    }

    // MARK: - Seasonal collections

    /// Gradient pairs cycled by position — collections rotate through the
    /// year, so stable-but-varied is all we need.
    private static let seasonalGradients: [[Color]] = [
        [.red, .orange], [.indigo, .purple], [.teal, .blue],
        [.pink, .red], [.orange, .yellow], [.green, .mint]
    ]

    private var seasonalSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Right Now")
                    .font(.title3.bold())
                Text("Collections for this time of year")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 16)

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 12) {
                    ForEach(Array(feed.seasonal.enumerated()), id: \.element.id) { index, collection in
                        NavigationLink(value: collection) {
                            seasonalCard(collection, colors: Self.seasonalGradients[index % Self.seasonalGradients.count])
                        }
                        .buttonStyle(PressableButtonStyle())
                        .simultaneousGesture(TapGesture().onEnded {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        })
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 4)
            }
        }
    }

    private func seasonalCard(_ collection: SeasonalCollection, colors: [Color]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(collection.emoji)
                .font(.system(size: 34))
            Spacer(minLength: 0)
            Text(collection.title)
                .font(.subheadline.bold())
                .foregroundStyle(.white)
                .multilineTextAlignment(.leading)
                .lineLimit(2)
                .shadow(color: .black.opacity(0.3), radius: 1, y: 1)
            if let subtitle = collection.subtitle {
                Text(subtitle)
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.85))
                    .lineLimit(1)
            }
        }
        .padding(14)
        .frame(width: 160, height: 120, alignment: .topLeading)
        .background(
            LinearGradient(colors: colors.map { $0.opacity(0.85) }, startPoint: .topLeading, endPoint: .bottomTrailing),
            in: RoundedRectangle(cornerRadius: 16)
        )
        .shadow(color: colors[0].opacity(0.35), radius: 6, y: 4)
    }

    private func rankedRow(title: String,
                           subtitle: String,
                           ranked: [NebRatingsStore.RankedShow],
                           badge: (NebRatingsStore.RankedShow) -> String) -> some View {
        ShowPosterRow(
            title: title,
            subtitle: subtitle,
            shows: ranked.map(\.show),
            badges: Dictionary(uniqueKeysWithValues: ranked.map { ($0.show.id, badge($0)) })
        )
    }

    private var favoriteGenresSubtitle: String? {
        guard let genres = store.currentUser?.favoriteGenres, !genres.isEmpty else { return nil }
        return genres.joined(separator: " · ")
    }
}

// MARK: - Mood results

/// Pushed when a mood chip is tapped: fetches the mood's movie + TV filters
/// and lists the merged results.
struct MoodResultsView: View {
    let mood: Mood

    @Environment(NebRatingsStore.self) private var store
    @State private var results: [Show] = []
    @State private var isLoading = true

    var body: some View {
        Group {
            if isLoading {
                ProgressView("Finding \(mood.name.lowercased()) picks…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if results.isEmpty {
                ContentUnavailableView(
                    "Nothing found",
                    systemImage: "sparkles",
                    description: Text("Try another mood.")
                )
            } else {
                List(results) { show in
                    NavigationLink(value: show) {
                        ShowRow(show: show)
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
        .navigationTitle("\(mood.emoji) \(mood.name)")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            var movies: [Show] = []
            var tv: [Show] = []
            if let movieFilter = mood.movieFilter {
                movies = await store.fetchDiscover(filter: movieFilter)
            }
            if let tvFilter = mood.tvFilter {
                tv = await store.fetchDiscover(filter: tvFilter)
            }
            // Mixed but stable: alternate media, movies first.
            var merged: [Show] = []
            var seen = Set<Int>()
            for index in 0..<max(movies.count, tv.count) {
                if index < movies.count, seen.insert(movies[index].id).inserted {
                    merged.append(movies[index])
                }
                if index < tv.count, seen.insert(tv[index].id).inserted {
                    merged.append(tv[index])
                }
            }
            results = merged
            isLoading = false
        }
    }
}

// MARK: - Seasonal results

/// Pushed when a seasonal collection card is tapped.
struct SeasonalResultsView: View {
    let collection: SeasonalCollection

    @Environment(NebRatingsStore.self) private var store
    @State private var results: [Show] = []
    @State private var isLoading = true

    var body: some View {
        Group {
            if isLoading {
                ProgressView("Gathering picks…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if results.isEmpty {
                ContentUnavailableView(
                    "Nothing found",
                    systemImage: "sparkles",
                    description: Text("This collection came up empty — check back soon.")
                )
            } else {
                List(results) { show in
                    NavigationLink(value: show) {
                        ShowRow(show: show)
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
        .navigationTitle("\(collection.emoji) \(collection.title)")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            results = await store.fetchShows(for: collection)
            isLoading = false
        }
    }
}

#Preview {
    NavigationStack {
        DiscoverHomeView()
            .environment(NebRatingsStore())
    }
}
