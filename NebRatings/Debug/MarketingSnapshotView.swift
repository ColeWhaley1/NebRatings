//
//  MarketingSnapshotView.swift
//  NebRatings
//
//  DEBUG-only harness for capturing real, on-device screenshots of key
//  screens (Discover, Compatibility, Wrapped) with polished sample data —
//  used for App Store preview screenshots and nebratings.com marketing,
//  without needing a signed-in account or live Firestore data.
//
//  Activated by launching with the NEBRATINGS_SNAPSHOT environment
//  variable set (see `xcrun simctl launch` with a SIMCTL_CHILD_ prefix).
//  Never compiled into release builds and inert unless that variable is
//  explicitly set, so it has no effect on normal app usage.
//

#if DEBUG
import SwiftUI

enum MarketingSnapshot: String {
    case discover
    case compatibility
    case wrapped

    static var requested: MarketingSnapshot? {
        ProcessInfo.processInfo.environment["NEBRATINGS_SNAPSHOT"].flatMap(MarketingSnapshot.init)
    }
}

struct MarketingSnapshotView: View {
    let kind: MarketingSnapshot

    var body: some View {
        switch kind {
        case .discover:
            DiscoverSnapshot()

        case .compatibility:
            NavigationStack {
                CompatibilityView(
                    otherUserID: "demo-friend",
                    otherProfile: Self.friendProfile,
                    snapshot: (report: Self.compatibilityReport, myAvatarEmoji: "🎬")
                )
            }
            .tint(.purple)
            .preferredColorScheme(.dark)

        case .wrapped:
            ZStack {
                LinearGradient(
                    colors: [Color(red: 0.13, green: 0.05, blue: 0.25), Color(red: 0.03, green: 0.02, blue: 0.08)],
                    startPoint: .top, endPoint: .bottom
                )
                .ignoresSafeArea()

                WrappedShareCard(stats: Self.wrappedStats, variant: .summary)
                    .scaleEffect(1.35)
            }
            .preferredColorScheme(.dark)
        }
    }

    // MARK: - Compatibility sample data

    // Fictional friend — deliberately not any real NebRatings user, so this
    // screen never surfaces a real person's name or taste data.
    private static let friendProfile = UserProfile(id: "demo-friend", username: "Jordan Ellis", avatarEmoji: "🌻")

    private static let compatibilityReport = CompatibilityReport(
        score: 89,
        sharedTitleCount: 34,
        bothLove: ["Sci-Fi", "Crime", "Thriller", "Comedy"],
        disagreeOn: ["Romance", "Horror"],
        sharedFavorites: [
            .init(showID: 1, title: "Severance", myRating: 9.4, theirRating: 9.6),
            .init(showID: 2, title: "Interstellar", myRating: 9.6, theirRating: 9.2),
            .init(showID: 3, title: "The Bear", myRating: 8.8, theirRating: 9.1),
            .init(showID: 5, title: "Parasite", myRating: 9.2, theirRating: 8.9),
            .init(showID: 6, title: "Oppenheimer", myRating: 8.9, theirRating: 9.3)
        ],
        biggestDifferences: [
            .init(showID: 4, title: "La La Land", myRating: 6.0, theirRating: 9.0),
            .init(showID: 7, title: "Barbie", myRating: 5.5, theirRating: 8.8),
            .init(showID: 8, title: "Whiplash", myRating: 9.5, theirRating: 7.0)
        ],
        isLowConfidence: false
    )

    // MARK: - Wrapped sample data

    private static let wrappedStats = YearInReviewStats(
        year: Calendar.current.component(.year, from: .now),
        moviesWatched: 142,
        showsWatched: 38,
        reviewsWritten: 163,
        listsCreated: 12,
        estimatedHours: 588,
        topGenres: [
            .init(name: "Sci-Fi", share: 0.28),
            .init(name: "Thriller", share: 0.19),
            .init(name: "Comedy", share: 0.15)
        ],
        favoriteMovie: Review(showID: 157336, showTitle: "Interstellar", showCategory: .movie, author: "Cole", comment: "", nebRating: 9.6),
        favoriteShow: Review(showID: 111803, showTitle: "Severance", showCategory: .series, author: "Cole", comment: "", nebRating: 9.4),
        hiddenGem: nil,
        favoriteNewRelease: nil,
        highestRatedSeason: nil,
        mostActiveMonth: "December",
        mostActiveWeekday: "Sunday",
        averageRating: 7.8,
        longestStreakDays: 9,
        favoriteDecade: "2010s",
        mostCompatibleFriend: nil,
        mostControversial: nil,
        biggestSurprise: nil
    )

    // MARK: - Discover sample feed

    /// Builds a Show carrying only what the poster rows need (id + title +
    /// poster art). Real TMDB CDN paths, mainstream titles only.
    private static func show(_ id: Int, _ title: String, _ category: Show.Category, _ posterPath: String) -> Show {
        Show(
            id: id,
            title: title,
            category: category,
            year: 2025,
            synopsis: "",
            tagline: "",
            streamingService: "",
            posterURL: "https://image.tmdb.org/t/p/w500\(posterPath)"
        )
    }

    static var sampleDiscoverFeed: NebRatingsStore.DiscoverFeed {
        var feed = NebRatingsStore.DiscoverFeed()

        feed.seasonal = [
            SeasonalCollection(id: "summer", title: "Summer Blockbusters", emoji: "🍿", subtitle: "Big, loud & fun", startMonth: 1, startDay: 1, endMonth: 12, endDay: 31),
            SeasonalCollection(id: "beach", title: "Beach Movies", emoji: "🏖️", subtitle: "Sun's out", startMonth: 1, startDay: 1, endMonth: 12, endDay: 31),
            SeasonalCollection(id: "date", title: "Date Night", emoji: "💜", subtitle: "For two", startMonth: 1, startDay: 1, endMonth: 12, endDay: 31)
        ]

        feed.trendingWeek = [
            show(1064213, "Dune: Part Three", .movie, "/b4wekkUaxExzOeGe7hKXzhnyXHt.jpg"),
            show(1022789, "Toy Story 5", .movie, "/wLvUuBF2Yj0JmMGLUdRRVu7LvNB.jpg"),
            show(94997, "House of the Dragon", .series, "/7V0Ebks0GgpKvQ7QbLAIdX5dos4.jpg"),
            show(125988, "Silo", .series, "/gMYZZvnkVNTqSVnVCphWbPXwWwb.jpg"),
            show(1241982, "Moana", .movie, "/zKVgiv5qHCvCLT4A2ymJi5QeXDH.jpg"),
            show(1000001, "X-Men '97", .series, "/2HKBc5UiFw8JrruHq8S1Y7TnlW0.jpg")
        ]

        feed.highestRatedMonth = [
            .init(show: show(278, "The Shawshank Redemption", .movie, "/9cqNxx0GxF0bflZmeSMuL5tnGzr.jpg"), averageRating: 9.6, reviewCount: 41),
            .init(show: show(238, "The Godfather", .movie, "/3bhkrj58Vtu7enYsRolD1fZdja1.jpg"), averageRating: 9.4, reviewCount: 33),
            .init(show: show(155, "The Dark Knight", .movie, "/qJ2tW6WMUDux911r6m7haRef0WH.jpg"), averageRating: 9.2, reviewCount: 58)
        ]

        feed.mostReviewedMonth = [
            .init(show: show(155, "The Dark Knight", .movie, "/qJ2tW6WMUDux911r6m7haRef0WH.jpg"), averageRating: 9.2, reviewCount: 58),
            .init(show: show(94997, "House of the Dragon", .series, "/7V0Ebks0GgpKvQ7QbLAIdX5dos4.jpg"), averageRating: 8.7, reviewCount: 47),
            .init(show: show(1022789, "Toy Story 5", .movie, "/wLvUuBF2Yj0JmMGLUdRRVu7LvNB.jpg"), averageRating: 8.5, reviewCount: 44)
        ]

        feed.highestRatedYear = [
            .init(show: show(496243, "Parasite", .movie, "/7IiTTgloJzvGI1TAYymCfbfl3vT.jpg"), averageRating: 9.3, reviewCount: 29),
            .init(show: show(872585, "Oppenheimer", .movie, "/8Gxv8gSFCU0XGDykEGv7zR1n2ua.jpg"), averageRating: 9.1, reviewCount: 52)
        ]

        feed.recentlyReleased = [
            show(1064213, "Dune: Part Three", .movie, "/b4wekkUaxExzOeGe7hKXzhnyXHt.jpg"),
            show(1241982, "Moana", .movie, "/zKVgiv5qHCvCLT4A2ymJi5QeXDH.jpg"),
            show(125988, "Silo", .series, "/gMYZZvnkVNTqSVnVCphWbPXwWwb.jpg")
        ]

        feed.hiddenGems = [
            show(129, "Spirited Away", .movie, "/39wmItIWsg5sZMyRUHLkWBcuVCM.jpg"),
            show(497, "The Green Mile", .movie, "/8VG8fDNiy50H4FedGwdSVUPoaJe.jpg")
        ]

        feed.awardWinners = [
            show(122, "The Lord of the Rings: The Return of the King", .movie, "/rCzpDGLbOoPwLjy3OAm5NUPOTrC.jpg"),
            show(424, "Schindler's List", .movie, "/sF1U4EUQS8YHUYjNl3pMGNIQyr0.jpg")
        ]

        feed.isLoaded = true
        return feed
    }
}

/// Owns a throwaway store pre-loaded with the sample Discover feed and hosts
/// the real Discover tab UI (SearchShowsView → DiscoverHomeView). Because the
/// feed is marked `isLoaded`, the view's own `preloadDiscover()` is a no-op,
/// so no network fetch overwrites the sample.
private struct DiscoverSnapshot: View {
    @State private var store: NebRatingsStore = {
        let store = NebRatingsStore()
        store.discoverFeed = MarketingSnapshotView.sampleDiscoverFeed
        return store
    }()

    var body: some View {
        SearchShowsView()
            .environment(store)
            .tint(.purple)
            .preferredColorScheme(.dark)
    }
}
#endif
