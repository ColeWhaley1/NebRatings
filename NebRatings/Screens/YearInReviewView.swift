//
//  YearInReviewView.swift
//  NebRatings
//
//  "NebRatings Wrapped" — a paged, full-screen annual recap with shareable
//  cards. Pages swipe horizontally (TabView page style) over a dark
//  gradient; the last page renders share cards to images (ImageRenderer)
//  for the iOS share sheet.
//

import SwiftUI
import UIKit

struct YearInReviewView: View {
    let year: Int

    @Environment(NebRatingsStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var stats: YearInReviewStats?
    @State private var page = 0
    @State private var shareItems: [Any] = []
    @State private var isSharePresented = false

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.13, green: 0.05, blue: 0.25), Color(red: 0.03, green: 0.02, blue: 0.08)],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea()

            if let stats {
                if stats.isEmpty {
                    emptyState
                } else {
                    TabView(selection: $page) {
                        overviewPage(stats).tag(0)
                        genresPage(stats).tag(1)
                        topRatedPage(stats).tag(2)
                        habitsPage(stats).tag(3)
                        if stats.mostCompatibleFriend != nil {
                            friendsPage(stats).tag(4)
                        }
                        funFactsPage(stats).tag(5)
                        sharePage(stats).tag(6)
                    }
                    .tabViewStyle(.page(indexDisplayMode: .always))
                    .indexViewStyle(.page(backgroundDisplayMode: .always))
                }
            } else {
                VStack(spacing: 14) {
                    ProgressView()
                        .controlSize(.large)
                        .tint(.white)
                    Text("Wrapping up your \(String(year))…")
                        .foregroundStyle(.white.opacity(0.8))
                }
            }

            // Close
            VStack {
                HStack {
                    Spacer()
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.white.opacity(0.7))
                    }
                    .padding(.trailing, 20)
                }
                Spacer()
            }
            .padding(.top, 8)
        }
        .task {
            stats = await store.buildYearInReview(year: year)
        }
        .sheet(isPresented: $isSharePresented) {
            ActivityShareSheet(items: shareItems)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Text("🌱")
                .font(.system(size: 60))
            Text("Not enough \(String(year)) activity yet")
                .font(.title3.bold())
                .foregroundStyle(.white)
            Text("Rate a few movies and shows, then come back for your Wrapped.")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.7))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
    }

    // MARK: - Pages

    private func pageScaffold<Content: View>(emoji: String,
                                             title: String,
                                             @ViewBuilder content: () -> Content) -> some View {
        VStack(spacing: 22) {
            Spacer()
            Text(emoji)
                .font(.system(size: 54))
            Text(title)
                .font(.system(.title, design: .rounded).bold())
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
            content()
            Spacer()
            Spacer()
        }
        .padding(.horizontal, 32)
    }

    private func bigStat(_ value: String, _ label: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
            Text(label)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.65))
        }
        .frame(maxWidth: .infinity)
    }

    private func statLine(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .foregroundStyle(.white.opacity(0.7))
            Spacer()
            Text(value)
                .bold()
                .foregroundStyle(.white)
        }
        .font(.subheadline)
    }

    private func overviewPage(_ stats: YearInReviewStats) -> some View {
        pageScaffold(emoji: "🎬", title: "Your \(String(year)) in Nebs") {
            VStack(spacing: 18) {
                HStack {
                    bigStat("\(stats.moviesWatched)", "Movies")
                    bigStat("\(stats.showsWatched)", "TV Shows")
                    bigStat("\(stats.reviewsWritten)", "Reviews")
                }
                HStack {
                    bigStat("\(stats.estimatedHours)h", "Est. Watched")
                    bigStat("\(stats.listsCreated)", "Lists Created")
                    bigStat(stats.averageRating.map { String(format: "%.1f", $0) } ?? "—", "Avg Rating")
                }
            }
            .padding(20)
            .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 20))
        }
    }

    private func genresPage(_ stats: YearInReviewStats) -> some View {
        pageScaffold(emoji: "🎭", title: "Your Top Genres") {
            if stats.topGenres.isEmpty {
                Text("Rate more titles to unlock genre stats.")
                    .foregroundStyle(.white.opacity(0.7))
            } else {
                VStack(spacing: 12) {
                    ForEach(Array(stats.topGenres.enumerated()), id: \.element.id) { index, genre in
                        HStack(spacing: 12) {
                            Text("\(index + 1)")
                                .font(.headline.bold())
                                .foregroundStyle(.white.opacity(0.5))
                                .frame(width: 22)
                            Text(genre.name)
                                .font(.headline)
                                .foregroundStyle(.white)
                            Spacer()
                            Text("\(Int((genre.share * 100).rounded()))%")
                                .font(.subheadline.bold())
                                .foregroundStyle(.purple.opacity(0.9))
                        }
                        .padding(.vertical, 10)
                        .padding(.horizontal, 16)
                        .background(
                            .white.opacity(0.08),
                            in: RoundedRectangle(cornerRadius: 12)
                        )
                    }
                }
            }
        }
    }

    private func topRatedPage(_ stats: YearInReviewStats) -> some View {
        pageScaffold(emoji: "🏆", title: "Your Top Rated") {
            VStack(spacing: 12) {
                if let movie = stats.favoriteMovie {
                    highlightRow("Favorite Movie", movie.showTitle, movie.nebRating)
                }
                if let show = stats.favoriteShow {
                    highlightRow("Favorite TV Show", show.showTitle, show.nebRating)
                }
                if let gem = stats.hiddenGem {
                    highlightRow("Hidden Gem", gem.showTitle, gem.nebRating)
                }
                if let release = stats.favoriteNewRelease {
                    highlightRow("Favorite New Release", release.showTitle, release.nebRating)
                }
                if let season = stats.highestRatedSeason, let number = season.season {
                    highlightRow("Best TV Season", "\(season.showTitle) S\(number)", season.nebRating)
                }
            }
        }
    }

    private func highlightRow(_ label: String, _ title: String, _ rating: Double) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label.uppercased())
                .font(.caption2.bold())
                .foregroundStyle(.purple.opacity(0.9))
            HStack {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Spacer()
                Text(String(format: "🔥 %.1f", rating))
                    .font(.subheadline.bold())
                    .foregroundStyle(.white.opacity(0.9))
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))
    }

    private func habitsPage(_ stats: YearInReviewStats) -> some View {
        pageScaffold(emoji: "📈", title: "Your Habits") {
            VStack(spacing: 14) {
                if let month = stats.mostActiveMonth {
                    statLine("Most active month", month)
                }
                if let weekday = stats.mostActiveWeekday {
                    statLine("Most active day", weekday)
                }
                if let avg = stats.averageRating {
                    statLine("Average rating", String(format: "%.1f nebs", avg))
                }
                if stats.longestStreakDays > 1 {
                    statLine("Longest review streak", "\(stats.longestStreakDays) days")
                }
                if let decade = stats.favoriteDecade {
                    statLine("Favorite decade", decade)
                }
            }
            .padding(20)
            .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 20))
        }
    }

    private func friendsPage(_ stats: YearInReviewStats) -> some View {
        pageScaffold(emoji: "💜", title: "Your People") {
            if let friend = stats.mostCompatibleFriend {
                VStack(spacing: 12) {
                    AvatarView(emoji: friend.profile.avatarEmoji, size: 72)
                    Text(friend.profile.username)
                        .font(.title3.bold())
                        .foregroundStyle(.white)
                    Text("\(friend.score)% compatible")
                        .font(.headline)
                        .foregroundStyle(.purple.opacity(0.95))
                    Text("Your movie twin of \(String(year))")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.6))
                }
                .padding(24)
                .frame(maxWidth: .infinity)
                .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 20))
            }
        }
    }

    private func funFactsPage(_ stats: YearInReviewStats) -> some View {
        pageScaffold(emoji: "🎉", title: "Fun Facts") {
            VStack(spacing: 12) {
                if let controversial = stats.mostControversial {
                    factCard(
                        "Most Controversial Take",
                        "\(controversial.review.showTitle) — you went \(String(format: "%+.1f", controversial.delta)) vs the world"
                    )
                }
                if let surprise = stats.biggestSurprise {
                    factCard(
                        "Biggest Surprise Favorite",
                        "\(surprise.review.showTitle) — you loved it way more than most"
                    )
                }
                if let genre = stats.topGenres.first {
                    factCard(
                        "Signature Genre",
                        "\(genre.name) showed up in \(Int((genre.share * 100).rounded()))% of your reviews"
                    )
                }
                if stats.mostControversial == nil && stats.biggestSurprise == nil && stats.topGenres.isEmpty {
                    Text("Rate more titles to unlock fun facts!")
                        .foregroundStyle(.white.opacity(0.7))
                }
            }
        }
    }

    private func factCard(_ label: String, _ text: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label.uppercased())
                .font(.caption2.bold())
                .foregroundStyle(.purple.opacity(0.9))
            Text(text)
                .font(.subheadline)
                .foregroundStyle(.white)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))
    }

    private func sharePage(_ stats: YearInReviewStats) -> some View {
        pageScaffold(emoji: "📤", title: "Share Your Wrapped") {
            VStack(spacing: 12) {
                shareButton("Year Summary Card") {
                    WrappedShareCard(stats: stats, variant: .summary)
                }
                if stats.favoriteMovie != nil {
                    shareButton("Favorite Movie Card") {
                        WrappedShareCard(stats: stats, variant: .favoriteMovie)
                    }
                }
                if stats.favoriteShow != nil {
                    shareButton("Favorite TV Show Card") {
                        WrappedShareCard(stats: stats, variant: .favoriteShow)
                    }
                }
                if !stats.topGenres.isEmpty {
                    shareButton("Top Genres Card") {
                        WrappedShareCard(stats: stats, variant: .topGenres)
                    }
                }
            }
        }
    }

    private func shareButton<Card: View>(_ title: String, @ViewBuilder card: @escaping () -> Card) -> some View {
        Button {
            share(card())
        } label: {
            Label(title, systemImage: "square.and.arrow.up")
                .font(.subheadline.bold())
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
        }
        .buttonStyle(.borderedProminent)
        .tint(.purple)
    }

    /// Renders a card view to an image and opens the share sheet via the
    /// shared ShareService (image + copy + a link to the sharer's profile).
    @MainActor
    private func share<Card: View>(_ card: Card) {
        let renderer = ImageRenderer(content: card)
        renderer.scale = 3 // crisp on social feeds
        guard let image = renderer.uiImage else { return }
        Task {
            shareItems = await ShareService.items(for: .yearInReview(
                year: year, card: image, sharerID: store.currentUser?.id
            ))
            isSharePresented = true
        }
    }
}

// MARK: - Share card

/// A fixed-size, self-contained card (no async content — ImageRenderer
/// snapshots synchronously) designed for social sharing.
struct WrappedShareCard: View {
    enum Variant {
        case summary
        case favoriteMovie
        case favoriteShow
        case topGenres
    }

    let stats: YearInReviewStats
    let variant: Variant

    var body: some View {
        VStack(spacing: 18) {
            Text("NEBRATINGS WRAPPED")
                .font(.caption.bold())
                .tracking(2)
                .foregroundStyle(.white.opacity(0.6))
            Text(String(stats.year))
                .font(.system(size: 46, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)

            switch variant {
            case .summary:
                summaryContent
            case .favoriteMovie:
                favoriteContent(label: "FAVORITE MOVIE", review: stats.favoriteMovie)
            case .favoriteShow:
                favoriteContent(label: "FAVORITE TV SHOW", review: stats.favoriteShow)
            case .topGenres:
                genresContent
            }

            Spacer(minLength: 0)
            Text("🔥 nebratings")
                .font(.caption.bold())
                .foregroundStyle(.white.opacity(0.5))
        }
        .padding(28)
        .frame(width: 340, height: 600)
        .background(
            LinearGradient(
                colors: [Color(red: 0.35, green: 0.12, blue: 0.6), Color(red: 0.05, green: 0.03, blue: 0.12)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 28))
    }

    private var summaryContent: some View {
        VStack(spacing: 14) {
            cardStat("\(stats.moviesWatched)", "movies watched")
            cardStat("\(stats.showsWatched)", "TV shows watched")
            cardStat("\(stats.reviewsWritten)", "reviews written")
            cardStat("\(stats.estimatedHours)h", "estimated watch time")
            if let genre = stats.topGenres.first {
                cardStat(genre.name, "top genre")
            }
        }
    }

    private func favoriteContent(label: String, review: Review?) -> some View {
        VStack(spacing: 10) {
            Text(label)
                .font(.caption.bold())
                .tracking(1.5)
                .foregroundStyle(.purple.opacity(0.95))
            Text(review?.showTitle ?? "—")
                .font(.system(.title, design: .rounded).bold())
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .lineLimit(3)
            if let rating = review?.nebRating {
                Text(String(format: "🔥 %.1f / 10", rating))
                    .font(.title3.bold())
                    .foregroundStyle(.white.opacity(0.9))
            }
        }
        .padding(.top, 20)
    }

    private var genresContent: some View {
        VStack(spacing: 12) {
            ForEach(Array(stats.topGenres.prefix(5).enumerated()), id: \.element.id) { index, genre in
                HStack {
                    Text("\(index + 1). \(genre.name)")
                        .font(.headline)
                        .foregroundStyle(.white)
                    Spacer()
                    Text("\(Int((genre.share * 100).rounded()))%")
                        .font(.headline)
                        .foregroundStyle(.purple.opacity(0.95))
                }
            }
        }
        .padding(.top, 8)
    }

    private func cardStat(_ value: String, _ label: String) -> some View {
        VStack(spacing: 1) {
            Text(value)
                .font(.system(size: 30, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
            Text(label)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.6))
        }
    }
}
