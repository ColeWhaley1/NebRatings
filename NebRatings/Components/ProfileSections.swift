//
//  ProfileSections.swift
//  NebRatings
//
//  Shared building blocks for profile screens (own ProfileView and read-only
//  UserProfileView): the About block (bio, favorite genres, favorite titles,
//  join date), the statistics block (counts, average, rating distribution),
//  monthly highlights, and a public-lists list. All are display-only — the
//  owning screens supply data and tap handlers.
//

import SwiftUI

// MARK: - About

struct ProfileAboutSection: View {
    let profile: UserProfile?
    /// Tap on the favorite movie/show card. nil = cards not tappable.
    var onOpenFavorite: ((FavoriteTitle) -> Void)? = nil

    private var hasAnyContent: Bool {
        guard let profile else { return false }
        return (profile.bio?.isEmpty == false)
            || (profile.favoriteGenres?.isEmpty == false)
            || profile.favoriteMovie != nil
            || profile.favoriteShow != nil
            || profile.joinDate != nil
    }

    var body: some View {
        if let profile, hasAnyContent {
            VStack(alignment: .leading, spacing: 14) {
                if let bio = profile.bio, !bio.isEmpty {
                    Text(bio)
                        .font(.subheadline)
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if let genres = profile.favoriteGenres, !genres.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        sectionLabel("Favorite Genres", systemImage: "theatermasks")
                        GenreChipsView(genres: genres)
                    }
                }

                if profile.favoriteMovie != nil || profile.favoriteShow != nil {
                    VStack(alignment: .leading, spacing: 8) {
                        sectionLabel("Favorites", systemImage: "star.fill")
                        HStack(spacing: 12) {
                            if let movie = profile.favoriteMovie {
                                FavoriteTitleCard(title: movie, slotLabel: "Favorite Movie", onTap: onOpenFavorite)
                            }
                            if let show = profile.favoriteShow {
                                FavoriteTitleCard(title: show, slotLabel: "Favorite TV Show", onTap: onOpenFavorite)
                            }
                        }
                    }
                }

                if let joinDate = profile.joinDate {
                    HStack(spacing: 6) {
                        Image(systemName: "calendar")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("Joined \(joinDate.formatted(.dateTime.month(.wide).year()))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func sectionLabel(_ title: String, systemImage: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: systemImage)
                .font(.caption)
                .foregroundStyle(.purple)
            Text(title)
                .font(.subheadline.bold())
                .foregroundStyle(.secondary)
        }
    }
}

/// Wrapping chips for genre names.
struct GenreChipsView: View {
    let genres: [String]

    var body: some View {
        FlowLayout(spacing: 8) {
            ForEach(genres, id: \.self) { genre in
                Text(genre)
                    .font(.caption.bold())
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.purple.opacity(0.12), in: Capsule())
                    .foregroundStyle(.purple)
            }
        }
    }
}

/// Small poster card for a hand-picked favorite title.
private struct FavoriteTitleCard: View {
    let title: FavoriteTitle
    let slotLabel: String
    let onTap: ((FavoriteTitle) -> Void)?

    var body: some View {
        let content = VStack(alignment: .leading, spacing: 6) {
            ZStack {
                if let posterURL = title.posterURL {
                    AsyncImageView(urlString: posterURL)
                } else {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.gray.opacity(0.2))
                        .overlay(
                            Image(systemName: title.category == .movie ? "film" : "tv")
                                .foregroundStyle(.secondary)
                        )
                }
            }
            .frame(width: 100, height: 150)
            .clipShape(RoundedRectangle(cornerRadius: 10))

            Text(slotLabel)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(title.title)
                .font(.caption.bold())
                .foregroundStyle(.primary)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
        }
        .frame(width: 100, alignment: .leading)

        if let onTap {
            Button {
                onTap(title)
            } label: {
                content
            }
            .buttonStyle(.plain)
        } else {
            content
        }
    }
}

/// Minimal wrapping layout for chips. Rows fill left-to-right and wrap when
/// the next chip would overflow the proposed width.
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = computeRows(proposal: proposal, subviews: subviews)
        let width = proposal.width ?? rows.map(\.width).max() ?? 0
        let height = rows.reduce(0) { $0 + $1.height } + spacing * CGFloat(max(0, rows.count - 1))
        return CGSize(width: width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let rows = computeRows(proposal: proposal, subviews: subviews)
        var y = bounds.minY
        for row in rows {
            var x = bounds.minX
            for index in row.indices {
                let size = subviews[index].sizeThatFits(.unspecified)
                subviews[index].place(at: CGPoint(x: x, y: y), proposal: .unspecified)
                x += size.width + spacing
            }
            y += row.height + spacing
        }
    }

    private struct Row {
        var indices: [Int] = []
        var width: CGFloat = 0
        var height: CGFloat = 0
    }

    private func computeRows(proposal: ProposedViewSize, subviews: Subviews) -> [Row] {
        let maxWidth = proposal.width ?? .infinity
        var rows: [Row] = []
        var current = Row()

        for (index, subview) in subviews.enumerated() {
            let size = subview.sizeThatFits(.unspecified)
            let needed = current.indices.isEmpty ? size.width : current.width + spacing + size.width
            if needed > maxWidth && !current.indices.isEmpty {
                rows.append(current)
                current = Row()
            }
            current.width = current.indices.isEmpty ? size.width : current.width + spacing + size.width
            current.height = max(current.height, size.height)
            current.indices.append(index)
        }
        if !current.indices.isEmpty {
            rows.append(current)
        }
        return rows
    }
}

// MARK: - Statistics

struct ProfileStatsSection: View {
    /// All of the user's reviews (drives counts, average, distribution,
    /// and monthly highlights).
    let reviews: [Review]
    /// nil hides the tile (e.g. query failed or not applicable).
    var publicListCount: Int? = nil
    var friendCount: Int? = nil
    /// Tap on a monthly-highlight card; receives the underlying review.
    var onOpenHighlight: ((Review) -> Void)? = nil

    private var movieCount: Int {
        Set(reviews.filter { $0.showCategory == .movie }.map(\.showID)).count
    }

    private var seriesCount: Int {
        Set(reviews.filter { $0.showCategory == .series }.map(\.showID)).count
    }

    private var averageRating: Double? {
        guard !reviews.isEmpty else { return nil }
        return reviews.reduce(0.0) { $0 + $1.nebRating } / Double(reviews.count)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 6) {
                Image(systemName: "chart.bar.fill")
                    .font(.caption)
                    .foregroundStyle(.purple)
                Text("Statistics")
                    .font(.subheadline.bold())
                    .foregroundStyle(.secondary)
            }

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 96), spacing: 10)], spacing: 10) {
                statTile(value: "\(movieCount)", label: "Movies Rated")
                statTile(value: "\(seriesCount)", label: "TV Shows Rated")
                statTile(value: "\(reviews.count)", label: "Reviews")
                if let averageRating {
                    statTile(value: String(format: "%.1f", averageRating), label: "Avg Rating")
                }
                if let friendCount {
                    statTile(value: "\(friendCount)", label: friendCount == 1 ? "Friend" : "Friends")
                }
                if let publicListCount {
                    statTile(value: "\(publicListCount)", label: publicListCount == 1 ? "Public List" : "Public Lists")
                }
            }

            if !reviews.isEmpty {
                RatingDistributionView(ratings: reviews.map(\.nebRating))
            }

            MonthlyHighlightsView(reviews: reviews, onOpen: onOpenHighlight)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func statTile(value: String, label: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.title3.bold())
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 10))
    }
}

/// Compact 10-bin histogram of neb ratings (bin k = ratings in (k-1, k],
/// with 0 landing in bin 1). Bars scale to the fullest bin.
struct RatingDistributionView: View {
    let ratings: [Double]

    private var bins: [Int] {
        var counts = Array(repeating: 0, count: 10)
        for rating in ratings {
            // ceil puts e.g. 7.1–8.0 in bin 8; clamp handles 0 and 10.
            let bin = min(max(Int(rating.rounded(.up)), 1), 10)
            counts[bin - 1] += 1
        }
        return counts
    }

    var body: some View {
        let counts = bins
        let maxCount = max(counts.max() ?? 1, 1)

        VStack(alignment: .leading, spacing: 6) {
            Text("Rating Distribution")
                .font(.caption.bold())
                .foregroundStyle(.secondary)

            HStack(alignment: .bottom, spacing: 4) {
                ForEach(0..<10, id: \.self) { index in
                    VStack(spacing: 3) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.purple.opacity(counts[index] == 0 ? 0.15 : 0.75))
                            .frame(height: counts[index] == 0
                                   ? 3
                                   : max(6, 46 * CGFloat(counts[index]) / CGFloat(maxCount)))
                        Text("\(index + 1)")
                            .font(.system(size: 8))
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 62, alignment: .bottom)
        }
        .padding(12)
        .frame(maxWidth: .infinity)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 10))
    }
}

/// "Highest rated this month" cards — one for movies, one for TV shows.
/// Renders nothing when the user hasn't reviewed anything this month.
struct MonthlyHighlightsView: View {
    let reviews: [Review]
    var onOpen: ((Review) -> Void)? = nil

    private func topThisMonth(_ category: Show.Category) -> Review? {
        let calendar = Calendar.current
        let now = Date()
        return reviews
            .filter {
                $0.showCategory == category
                    && calendar.isDate($0.timestamp, equalTo: now, toGranularity: .month)
            }
            .max { lhs, rhs in
                if lhs.nebRating != rhs.nebRating { return lhs.nebRating < rhs.nebRating }
                return lhs.timestamp < rhs.timestamp
            }
    }

    var body: some View {
        let topMovie = topThisMonth(.movie)
        let topShow = topThisMonth(.series)

        if topMovie != nil || topShow != nil {
            VStack(alignment: .leading, spacing: 8) {
                Text("This Month's Highest Rated")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)

                VStack(spacing: 8) {
                    if let topMovie {
                        highlightRow(review: topMovie, slotLabel: "Movie")
                    }
                    if let topShow {
                        highlightRow(review: topShow, slotLabel: "TV Show")
                    }
                }
            }
        }
    }

    private func highlightRow(review: Review, slotLabel: String) -> some View {
        let content = HStack(spacing: 10) {
            Image(systemName: review.showCategory == .movie ? "film" : "tv")
                .font(.body)
                .foregroundStyle(.purple)
                .frame(width: 26)

            VStack(alignment: .leading, spacing: 2) {
                Text(review.showTitle)
                    .font(.subheadline.bold())
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Text(slotLabel)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 8)

            Text(String(format: "%.1f", review.nebRating))
                .font(.subheadline.bold())
                .foregroundStyle(.purple)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Color.purple.opacity(0.12), in: Capsule())
        }
        .padding(10)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 10))

        return Group {
            if let onOpen {
                Button {
                    onOpen(review)
                } label: {
                    content
                }
                .buttonStyle(.plain)
            } else {
                content
            }
        }
    }
}

// MARK: - Public lists

/// Read-only list of another user's visible lists (public + friends-only
/// when the viewer qualifies). Rows are informational.
struct VisibleListsSection: View {
    let lists: [ShowList]

    var body: some View {
        if !lists.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: "list.bullet.rectangle")
                        .font(.caption)
                        .foregroundStyle(.purple)
                    Text("Lists")
                        .font(.subheadline.bold())
                        .foregroundStyle(.secondary)
                }

                VStack(spacing: 8) {
                    ForEach(lists) { list in
                        HStack(spacing: 10) {
                            Image(systemName: list.visibility.icon)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .frame(width: 22)
                            Text(list.name)
                                .font(.subheadline)
                                .foregroundStyle(.primary)
                                .lineLimit(1)
                            Spacer(minLength: 8)
                            Text("\(list.showReferences.count) \(list.showReferences.count == 1 ? "item" : "items")")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(10)
                        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 10))
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

// MARK: - Previews

#Preview("About + Stats") {
    ScrollView {
        VStack(spacing: 20) {
            ProfileAboutSection(profile: UserProfile(
                id: "u1",
                username: "nebula_critic",
                bio: "Sci-fi devotee. I rate hard but fair. Extra neb for practical effects.",
                favoriteGenres: ["Science Fiction", "Thriller", "Animation"],
                favoriteMovie: FavoriteTitle(id: 603, title: "The Matrix", posterURL: nil, category: .movie),
                favoriteShow: FavoriteTitle(id: 1396, title: "Breaking Bad", posterURL: nil, category: .series),
                joinDate: Date(timeIntervalSinceNow: -86400 * 400)
            ))
            ProfileStatsSection(
                reviews: Review.sampleData,
                publicListCount: 2,
                friendCount: 7
            )
        }
        .padding()
    }
    .background(Color(.systemGroupedBackground))
}
