//
//  MarketingSnapshotView.swift
//  NebRatings
//
//  DEBUG-only harness for capturing real, on-device screenshots of key
//  screens with polished sample data — used for App Store preview
//  screenshots and nebratings.com marketing, without needing a signed-in
//  account or live Firestore data. Screens are composed from the app's own
//  components (ShowRow, ReviewCard, NebRatingView, …) so they look exactly
//  like the shipping UI.
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
    case search
    case rate
    case watchlist
    case friends
    case sharelist

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

        case .search:    SearchSnapshot()
        case .rate:      RateSnapshot()
        case .watchlist: WatchlistSnapshot()
        case .friends:   FriendsSnapshot()
        case .sharelist: ShareListSnapshot()
        }
    }

    // MARK: - Compatibility sample data

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

    private static func show(_ id: Int, _ title: String, _ category: Show.Category, _ posterPath: String) -> Show {
        Show(id: id, title: title, category: category, year: 2025, synopsis: "", tagline: "", streamingService: "",
             posterURL: "https://image.tmdb.org/t/p/w500\(posterPath)")
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
        feed.popularMovies = [
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

// MARK: - Shared dummy data for scenario screens

private enum Snap {
    static func poster(_ path: String) -> String { "https://image.tmdb.org/t/p/w500\(path)" }

    /// A Show carrying poster art, a short synopsis, and a synthetic review
    /// set so `ShowRow`'s average-rating badge renders.
    static func show(_ id: Int, _ title: String, _ cat: Show.Category, _ year: Int,
                     _ path: String, _ synopsis: String, avg: Double, count: Int) -> Show {
        let reviews = (0..<count).map { i in
            Review(showID: id, showTitle: title, showCategory: cat, author: "u\(i)", comment: "", nebRating: avg)
        }
        return Show(id: id, title: title, category: cat, year: year, synopsis: synopsis,
                    tagline: "", streamingService: "", posterURL: poster(path),
                    genres: [], rating: avg, numberOfSeasons: cat == .series ? 3 : nil, reviews: reviews)
    }

    static func review(_ author: String, _ authorID: String, on show: Show, nebs: Double,
                       _ comment: String, reactions: [String: String] = [:]) -> Review {
        Review(showID: show.id, showTitle: show.title, showCategory: show.category,
               author: author, authorID: authorID, comment: comment, nebRating: nebs,
               timestamp: Date(), season: nil, reactions: reactions)
    }

    // Titles reused across scenarios.
    static let dune = show(1064213, "Dune: Part Three", .movie, 2026, "/b4wekkUaxExzOeGe7hKXzhnyXHt.jpg",
                           "Paul Atreides leads the Fremen in a final reckoning for control of Arrakis.", avg: 9.1, count: 128)
    static let oppenheimer = show(872585, "Oppenheimer", .movie, 2023, "/8Gxv8gSFCU0XGDykEGv7zR1n2ua.jpg",
                                  "The story of J. Robert Oppenheimer and the race to build the atomic bomb.", avg: 9.0, count: 214)
    static let parasite = show(496243, "Parasite", .movie, 2019, "/7IiTTgloJzvGI1TAYymCfbfl3vT.jpg",
                               "A poor family schemes their way into the employ of a wealthy household.", avg: 9.3, count: 173)
    static let darkKnight = show(155, "The Dark Knight", .movie, 2008, "/qJ2tW6WMUDux911r6m7haRef0WH.jpg",
                                 "Batman faces the Joker, a criminal mastermind bent on plunging Gotham into chaos.", avg: 9.2, count: 302)
    static let silo = show(125988, "Silo", .series, 2023, "/gMYZZvnkVNTqSVnVCphWbPXwWwb.jpg",
                           "Thousands live in a giant underground silo, forbidden to know why.", avg: 8.6, count: 66)
    static let hotd = show(94997, "House of the Dragon", .series, 2022, "/7V0Ebks0GgpKvQ7QbLAIdX5dos4.jpg",
                           "The Targaryen civil war tears a dynasty — and a realm — apart.", avg: 8.5, count: 141)
    static let spirited = show(129, "Spirited Away", .movie, 2001, "/39wmItIWsg5sZMyRUHLkWBcuVCM.jpg",
                               "A young girl wanders into a world of spirits and must find her way home.", avg: 9.1, count: 98)
    static let shawshank = show(278, "The Shawshank Redemption", .movie, 1994, "/9cqNxx0GxF0bflZmeSMuL5tnGzr.jpg",
                                "Two imprisoned men bond over years, finding solace and eventual redemption.", avg: 9.6, count: 240)
    static let rotk = show(122, "The Return of the King", .movie, 2003, "/rCzpDGLbOoPwLjy3OAm5NUPOTrC.jpg",
                           "The final stand against Sauron as the Ring nears the fires of Mount Doom.", avg: 9.4, count: 188)
    static let toy = show(1022789, "Toy Story 5", .movie, 2026, "/wLvUuBF2Yj0JmMGLUdRRVu7LvNB.jpg",
                          "The toys face their biggest adventure yet.", avg: 8.4, count: 51)
}

// MARK: - 1. Search ("Find your next watch")

private struct SearchSnapshot: View {
    private let results = [Snap.oppenheimer, Snap.parasite, Snap.darkKnight, Snap.silo, Snap.dune]

    var body: some View {
        NavigationStack {
            List {
                ForEach(results) { show in
                    ShowRow(show: show)
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Discover")
            .searchable(text: .constant("thriller"), prompt: "Search movies or TV shows")
        }
        .tint(.purple)
        .preferredColorScheme(.dark)
    }
}

// MARK: - 2. Rate ("on a scale of 0 to 10")

private struct RateSnapshot: View {
    private let show = Snap.oppenheimer
    @State private var nebs = 8.5

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    AsyncImageView(urlString: show.posterURL)
                        .frame(width: 150, height: 225)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .shadow(color: .black.opacity(0.4), radius: 10, y: 6)
                        .padding(.top, 8)

                    VStack(spacing: 4) {
                        Text(show.title)
                            .font(.title2.bold())
                            .multilineTextAlignment(.center)
                        Text("Movie · \(String(show.year))")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    ratingCard
                        .padding(.horizontal, 16)
                }
                .padding(.bottom, 24)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Rate")
            .navigationBarTitleDisplayMode(.inline)
        }
        .tint(.purple)
        .preferredColorScheme(.dark)
    }

    private var ratingCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Drop Your Nebs")
                .font(.title3.bold())

            Text("Rating")
                .font(.subheadline.bold())
            Slider(value: $nebs, in: 0...10, step: 0.1)
                .tint(.purple)

            HStack {
                Image(systemName: "minus.circle.fill")
                    .font(.title2).foregroundStyle(.white.opacity(0.4))
                Spacer()
                NebRatingView(rating: nebs)
                Spacer()
                Image(systemName: "plus.circle.fill")
                    .font(.title2).foregroundStyle(.white.opacity(0.4))
            }

            Text("Comment")
                .font(.subheadline.bold())
                .padding(.top, 4)
            Text("Three hours flew by. That third act is an absolute gut punch — the best film I've seen all year.")
                .font(.body)
                .frame(maxWidth: .infinity, minHeight: 96, alignment: .topLeading)
                .padding(10)
                .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(.separator), lineWidth: 1))

            Label("Post Review", systemImage: "paperplane.fill")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color.purple, in: RoundedRectangle(cornerRadius: 12))
                .foregroundStyle(.white)
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18))
    }
}

// MARK: - 3. Watchlist ("Build watchlists fast")

private struct WatchlistSnapshot: View {
    private let shows = [Snap.dune, Snap.oppenheimer, Snap.hotd, Snap.spirited, Snap.shawshank]

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Picker("Filter", selection: .constant("All")) {
                        Text("All").tag("All")
                        Text("Movies").tag("Movies")
                        Text("TV Shows").tag("TV Shows")
                    }
                    .pickerStyle(.segmented)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))

                    ForEach(shows) { show in
                        ShowRow(show: show)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Weekend Watchlist")
        }
        .tint(.purple)
        .preferredColorScheme(.dark)
    }
}

// MARK: - 4. Friends' reviews ("See what friends are reviewing")

private struct FriendsSnapshot: View {
    private var cards: [(review: Review, show: Show, avatar: String)] {
        [
            (Snap.review("Chip", "chip", on: Snap.dune, nebs: 9.2,
                         "Villeneuve did it again — the scale on the big screen is unreal. Instant classic.",
                         reactions: ["a": "🔥", "b": "🔥", "c": "❤️"]),
             Snap.dune, "🍿"),
            (Snap.review("Gus", "gus", on: Snap.hotd, nebs: 8.5,
                         "The dragons finally deliver. That mid-season episode had me pacing my living room.",
                         reactions: ["a": "❤️", "b": "😂"]),
             Snap.hotd, "🧔"),
            (Snap.review("Mickey", "mickey", on: Snap.oppenheimer, nebs: 9.0,
                         "Three hours flew by. The tension never lets up. Best of the year for me.",
                         reactions: ["a": "🔥"]),
             Snap.oppenheimer, "🐭"),
            (Snap.review("Cali", "cali", on: Snap.silo, nebs: 8.6,
                         "A slow burn that absolutely pays off. Already need season three.",
                         reactions: ["a": "❤️", "b": "🔥"]),
             Snap.silo, "🌊")
        ]
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Text("From Your Friends")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 20)
                        .padding(.top, 8)

                    ForEach(cards, id: \.review.id) { item in
                        ReviewCard(
                            review: item.review,
                            showTitle: item.show.title,
                            showCategory: item.show.category,
                            authorAvatarEmoji: item.avatar,
                            isFriend: true,
                            useLighterBackground: true,
                            currentUserID: "viewer",
                            onReact: { _ in }
                        )
                        .padding(.horizontal, 16)
                    }
                }
                .padding(.bottom, 24)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Friends' Nebs")
            .navigationBarTitleDisplayMode(.inline)
        }
        .tint(.purple)
        .preferredColorScheme(.dark)
    }
}

// MARK: - 5. Shared list ("invite friends to contribute")

private struct ShareListSnapshot: View {
    private let shows = [Snap.darkKnight, Snap.parasite, Snap.rotk, Snap.spirited, Snap.toy]
    private let contributors = ["Chip", "Gus", "Mickey", "Cali"]

    var body: some View {
        NavigationStack {
            List {
                Section("Collaborators") {
                    HStack {
                        Image(systemName: "crown.fill").foregroundStyle(.yellow).frame(width: 24)
                        Text("Winston").font(.body)
                        Spacer()
                        Text("Owner").font(.caption).foregroundStyle(.secondary)
                    }
                    ForEach(contributors, id: \.self) { name in
                        HStack {
                            Image(systemName: "person.fill").foregroundStyle(.secondary).frame(width: 24)
                            Text(name).font(.body)
                            Spacer()
                        }
                    }
                    Label("Add Contributor", systemImage: "person.badge.plus")
                        .foregroundStyle(.purple)
                }

                Section {
                    HStack {
                        Image(systemName: "person.2.fill").foregroundStyle(.secondary).frame(width: 24)
                        Text("Friends Only").font(.body)
                        Spacer()
                    }
                } header: {
                    Text("Visibility")
                } footer: {
                    Text("Only your friends can see this list.")
                }

                Section("5 titles") {
                    ForEach(shows) { show in
                        ShowRow(show: show)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Movie Night Picks")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Image(systemName: "square.and.arrow.up").foregroundStyle(.purple)
                }
            }
        }
        .tint(.purple)
        .preferredColorScheme(.dark)
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
