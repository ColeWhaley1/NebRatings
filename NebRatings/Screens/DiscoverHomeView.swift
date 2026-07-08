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

    @State private var trendingWeek: [Show] = []
    @State private var recentlyReleased: [Show] = []
    @State private var hiddenGems: [Show] = []
    /// Collections active for today's date (Christmas, Halloween Horror, …).
    @State private var seasonalCollections: [SeasonalCollection] = []
    @State private var awardWinners: [Show] = []
    @State private var favoriteGenreShows: [Show] = []
    @State private var becauseYouRatedTitle: String?
    @State private var becauseYouRatedShows: [Show] = []
    @State private var highestRatedMonth: [NebRatingsStore.RankedShow] = []
    @State private var mostReviewedMonth: [NebRatingsStore.RankedShow] = []
    @State private var highestRatedYear: [NebRatingsStore.RankedShow] = []

    @State private var isLoading = true
    @State private var hasLoaded = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                moodsSection

                if !seasonalCollections.isEmpty {
                    seasonalSection
                }

                if isLoading {
                    HStack {
                        Spacer()
                        ProgressView("Curating…")
                        Spacer()
                    }
                    .padding(.vertical, 40)
                } else {
                    ShowPosterRow(title: "Trending This Week", shows: trendingWeek)

                    rankedRow(
                        title: "Highest Rated This Month",
                        subtitle: "Rated by the NebRatings community",
                        ranked: highestRatedMonth,
                        badge: { String(format: "🔥 %.1f", $0.averageRating) }
                    )

                    rankedRow(
                        title: "Most Reviewed This Month",
                        subtitle: "What the community is talking about",
                        ranked: mostReviewedMonth,
                        badge: { "\($0.reviewCount) \($0.reviewCount == 1 ? "review" : "reviews")" }
                    )

                    if let becauseYouRatedTitle {
                        ShowPosterRow(
                            title: "Because You Rated \(becauseYouRatedTitle) Highly",
                            shows: becauseYouRatedShows
                        )
                    }

                    ShowPosterRow(
                        title: "Based on Your Favorite Genres",
                        subtitle: favoriteGenresSubtitle,
                        shows: favoriteGenreShows
                    )

                    rankedRow(
                        title: "Highest Rated This Year",
                        subtitle: "The community's \(Calendar.current.component(.year, from: Date())) favorites",
                        ranked: highestRatedYear,
                        badge: { String(format: "🔥 %.1f", $0.averageRating) }
                    )

                    ShowPosterRow(title: "Recently Released", shows: recentlyReleased)
                    ShowPosterRow(title: "Hidden Gems", subtitle: "Great, but under the radar", shows: hiddenGems)
                    ShowPosterRow(title: "Award Winners", subtitle: "All-time critical darlings", shows: awardWinners)
                }
            }
            .padding(.vertical, 12)
        }
        .task {
            await loadAll()
        }
        .refreshable {
            hasLoaded = false
            await loadAll()
        }
        .onChange(of: store.contentPreference) { _, _ in
            // Changing the maturity level in Settings invalidates every
            // curated row — rebuild the page against the new preference.
            hasLoaded = false
            isLoading = true
            Task { await loadAll() }
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
                                    .shadow(color: .black.opacity(0.25), radius: 1, y: 1)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
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
                    ForEach(Array(seasonalCollections.enumerated()), id: \.element.id) { index, collection in
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

    // MARK: - Loading

    private func loadAll() async {
        guard !hasLoaded else { return }
        hasLoaded = true
        isLoading = trendingWeek.isEmpty

        let now = Date()
        let calendar = Calendar.current
        let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: now)) ?? now
        let yearStart = calendar.date(from: calendar.dateComponents([.year], from: now)) ?? now
        let sixtyDaysAgo = calendar.date(byAdding: .day, value: -60, to: now) ?? now

        // TMDB rows — all independent, fetched concurrently.
        async let seasonalFetch = store.fetchActiveSeasonalCollections()
        async let trendingFetch = store.fetchTrendingWeek()
        async let recentMoviesFetch = store.fetchDiscover(filter: DiscoverFilter(
            category: .movie, minVoteCount: 50, releasedAfter: sixtyDaysAgo, releasedBefore: now
        ))
        async let recentTVFetch = store.fetchDiscover(filter: DiscoverFilter(
            category: .series, minVoteCount: 20, releasedAfter: sixtyDaysAgo, releasedBefore: now
        ))
        async let gemMoviesFetch = store.fetchDiscover(filter: DiscoverFilter(
            category: .movie, minVoteAverage: 7.2, minVoteCount: 50, maxVoteCount: 500, sortBy: "vote_average.desc"
        ))
        async let gemTVFetch = store.fetchDiscover(filter: DiscoverFilter(
            category: .series, minVoteAverage: 7.5, minVoteCount: 30, maxVoteCount: 300, sortBy: "vote_average.desc"
        ))
        async let acclaimedMoviesFetch = store.fetchDiscover(filter: DiscoverFilter(
            category: .movie, minVoteCount: 5000, sortBy: "vote_average.desc"
        ))
        async let acclaimedTVFetch = store.fetchDiscover(filter: DiscoverFilter(
            category: .series, minVoteCount: 2000, sortBy: "vote_average.desc"
        ))

        // Community rankings (two windows, one review query each).
        async let monthRankings = store.fetchCommunityRankings(since: monthStart)
        async let yearRankings = store.fetchCommunityRankings(since: yearStart)

        seasonalCollections = await seasonalFetch
        trendingWeek = await trendingFetch
        recentlyReleased = interleave(await recentMoviesFetch, await recentTVFetch)
        hiddenGems = interleave(await gemMoviesFetch, await gemTVFetch)
        awardWinners = interleave(await acclaimedMoviesFetch, await acclaimedTVFetch)

        let month = await monthRankings
        highestRatedMonth = month.highestRated
        mostReviewedMonth = month.mostReviewed
        highestRatedYear = (await yearRankings).highestRated

        await loadPersonalizedRows()

        isLoading = false
    }

    /// "Because You Rated X Highly" + "Based on Your Favorite Genres".
    private func loadPersonalizedRows() async {
        // Seed: the user's highest-rated review (8+), most recent on ties.
        if let seed = store.userReviews
            .filter({ $0.nebRating >= 8 })
            .max(by: { lhs, rhs in
                if lhs.nebRating != rhs.nebRating { return lhs.nebRating < rhs.nebRating }
                return lhs.timestamp < rhs.timestamp
            }) {
            let recs = await store.fetchRecommendationsDetached(tmdbID: seed.showID, category: seed.showCategory)
            if !recs.isEmpty {
                becauseYouRatedTitle = seed.showTitle
                becauseYouRatedShows = recs
            }
        }

        if let genres = store.currentUser?.favoriteGenres, !genres.isEmpty {
            let movieIDs = genres.compactMap { GenreCatalog.tmdbGenreIDs[$0] }
            let tvIDs = genres.compactMap { GenreCatalog.tmdbTVGenreIDs[$0] ?? GenreCatalog.tmdbGenreIDs[$0] }
            async let movies = store.fetchDiscover(filter: DiscoverFilter(
                category: .movie, genreIDs: movieIDs, genreMatch: .any, minVoteAverage: 6.8, minVoteCount: 300
            ))
            async let tv = store.fetchDiscover(filter: DiscoverFilter(
                category: .series, genreIDs: Array(Set(tvIDs)), genreMatch: .any, minVoteAverage: 7.2, minVoteCount: 150
            ))
            favoriteGenreShows = interleave(await movies, await tv)
        }
    }

    /// Merges movie + TV results into one visually-mixed row.
    private func interleave(_ first: [Show], _ second: [Show]) -> [Show] {
        var result: [Show] = []
        var seen = Set<Int>()
        let maxCount = max(first.count, second.count)
        for index in 0..<maxCount {
            if index < first.count, !seen.contains(first[index].id) {
                seen.insert(first[index].id)
                result.append(first[index])
            }
            if index < second.count, !seen.contains(second[index].id) {
                seen.insert(second[index].id)
                result.append(second[index])
            }
        }
        return result
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
