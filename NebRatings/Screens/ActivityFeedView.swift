//
//  ActivityFeedView.swift
//  NebRatings
//
//  The Activity tab (replaces the Reviews tab). A segmented control switches
//  between the activity feed — rated / list / review-update events, friends
//  first — and the original friends-reviews feed (ReviewsFeedContent), which
//  keeps its reaction bars and filters.
//

import SwiftUI

struct ActivityTabView: View {
    private enum Mode: String, CaseIterable, Identifiable {
        case activity = "Activity"
        case reviews = "Reviews"
        var id: String { rawValue }
    }

    @Environment(NebRatingsStore.self) private var store
    @State private var mode: Mode = .activity
    @State private var navigationPath = NavigationPath()

    var body: some View {
        NavigationStack(path: $navigationPath) {
            Group {
                switch mode {
                case .activity:
                    ActivityFeedContent(navigationPath: $navigationPath)
                case .reviews:
                    ReviewsFeedContent(navigationPath: $navigationPath)
                }
            }
            .navigationTitle(mode == .activity ? "Activity" : "Friends' Nebs")
            // Inline, because a `.principal` toolbar item never renders while
            // a large title is displayed — the mode switcher would be invisible.
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Picker("Feed", selection: $mode) {
                        ForEach(Mode.allCases) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(maxWidth: 240)
                }
            }
            .navigationDestination(for: Show.self) { show in
                ShowDetailView(show: show)
            }
            .navigationDestination(for: ShowWithContext.self) { ctx in
                ShowDetailView(show: ctx.show, initialSeasonFilter: ctx.initialSeasonFilter)
            }
            .navigationDestination(for: UserProfileDestination.self) { dest in
                UserProfileView(userID: dest.userID, initialProfile: dest.profile)
            }
        }
    }
}

// MARK: - Feed

private struct ActivityFeedContent: View {
    @Environment(NebRatingsStore.self) private var store
    @Binding var navigationPath: NavigationPath

    @State private var activities: [Activity] = []
    @State private var isLoading = true

    /// Only friends' events — the viewer's own activity is deliberately
    /// excluded (the feed is for keeping up with other people, not yourself).
    private var friendActivities: [Activity] {
        // Blocked users are dropped instantly (Guideline 1.2), independent of
        // the friendship refresh that block also triggers.
        activities.filter { store.isFriend($0.userID) && !store.isBlocked($0.userID) }
    }

    /// "What the community is rating right now" — the shows drawing the most
    /// ratings recently. Reuses the Discover feed warmed during splash, so
    /// this section is already populated by the time the tab opens.
    private var communityTrending: [NebRatingsStore.RankedShow] {
        store.discoverFeed.mostReviewedMonth
    }

    var body: some View {
        List {
            if friendActivities.isEmpty && communityTrending.isEmpty {
                if isLoading || !store.discoverFeed.isLoaded {
                    HStack {
                        Spacer()
                        ProgressView()
                        Spacer()
                    }
                    .listRowSeparator(.hidden)
                } else {
                    ContentUnavailableView(
                        "No activity yet",
                        systemImage: "sparkles",
                        description: Text("Add friends to see what they're rating — or check back as the community gets going.")
                    )
                }
            } else {
                if !friendActivities.isEmpty {
                    Section("Friends") {
                        ForEach(friendActivities) { activity in
                            ActivityRow(activity: activity, navigationPath: $navigationPath)
                        }
                    }
                }
                if !communityTrending.isEmpty {
                    Section {
                        ForEach(Array(communityTrending.enumerated()), id: \.element.id) { index, ranked in
                            CommunityTrendingRow(rank: index + 1, ranked: ranked, navigationPath: $navigationPath)
                        }
                    } header: {
                        Text("Trending in the Community")
                    } footer: {
                        Text("Movies & shows getting the most ratings right now.")
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .task {
            // Warm the community rankings in parallel; the section fills in
            // reactively via the store's observable feed.
            Task { await store.preloadDiscover() }
            await load()
        }
        .refreshable {
            async let warm: Void = store.preloadDiscover(force: true)
            await load()
            await warm
        }
    }

    private func load() async {
        let feed = await store.fetchActivityFeed()
        // Warm avatars for everyone in the feed before rendering rows.
        await store.ensureProfilesLoaded(forAuthorIDs: feed.map(\.userID))
        activities = feed
        isLoading = false
    }
}

// MARK: - Row

private struct ActivityRow: View {
    let activity: Activity
    @Binding var navigationPath: NavigationPath

    @Environment(NebRatingsStore.self) private var store

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            // Avatar → author's profile (own → Profile tab).
            Button {
                openProfile()
            } label: {
                AvatarView(emoji: store.cachedProfile(for: activity.userID)?.avatarEmoji, size: 36)
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 3) {
                text
                    .font(.subheadline)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 6) {
                    if let rating = activity.rating {
                        RatingBadge(rating: rating)
                    }
                    if let season = activity.season {
                        Text("S\(season)")
                            .font(.caption2.bold())
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(Color.secondary.opacity(0.15), in: Capsule())
                            .foregroundStyle(.secondary)
                    }
                    Text(activity.timestamp.formatted(.relative(presentation: .named)))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, 2)
        .contentShape(Rectangle())
        .onTapGesture {
            openShow()
        }
    }

    /// "{user} rated {title}" and friends. The username and title are bolded
    /// inside one Text so it wraps naturally.
    private var text: Text {
        let user = Text(activity.username).bold()
        let title = Text(activity.showTitle ?? "").bold()
        let list = Text("“\(activity.listName ?? "")”").bold()
        switch activity.kind {
        case .rated:
            return user + Text(" rated ") + title
        case .updatedReview:
            return user + Text(" updated their review of ") + title
        case .createdList:
            return user + Text(" created the list ") + list
        case .addedToList:
            return user + Text(" added ") + title + Text(" to ") + list
        }
    }

    private func openProfile() {
        if activity.userID == store.currentUser?.id {
            store.selectedTab = .profile
        } else if !activity.userID.isEmpty {
            navigationPath.append(UserProfileDestination(
                userID: activity.userID,
                profile: store.cachedProfile(for: activity.userID)
            ))
        }
    }

    private func openShow() {
        guard let showID = activity.showID, let category = activity.showCategory else { return }
        if let cached = store.showCache[showID], cached.category == category {
            navigationPath.append(cached)
            return
        }
        Task {
            if let show = await store.fetchShowDetailsByTMDBID(tmdbID: showID, category: category) {
                navigationPath.append(show)
            }
        }
    }
}

// MARK: - Rating badge

/// A compact rating pill whose emoji mirrors the review cards: 🔥 for a great
/// score, 🤮 for a poor one, and no emoji (a neutral pill) in between. The tint
/// reflects the same sentiment so a bad rating never looks celebratory.
private struct RatingBadge: View {
    let rating: Double

    private var tint: Color {
        if rating >= 8.0 { return .purple }
        if rating <= 4.0 { return .red }
        return .secondary
    }

    var body: some View {
        HStack(spacing: 3) {
            if let emoji = ShowDetailHelpers.ratingEmoji(for: rating) {
                Text(emoji)
            }
            Text(String(format: "%.1f", rating))
                .fontWeight(.bold)
        }
        .font(.caption)
        .foregroundStyle(tint)
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(tint.opacity(0.14), in: Capsule())
    }
}

// MARK: - Community trending row

/// A single "what the community is rating" entry: rank, poster, title, how many
/// ratings it's pulling in, and the community's average (with mirrored emoji).
private struct CommunityTrendingRow: View {
    let rank: Int
    let ranked: NebRatingsStore.RankedShow
    @Binding var navigationPath: NavigationPath

    var body: some View {
        Button {
            navigationPath.append(ranked.show)
        } label: {
            HStack(spacing: 12) {
                Text("\(rank)")
                    .font(.subheadline.bold())
                    .foregroundStyle(.purple)
                    .frame(width: 18)

                posterThumb

                VStack(alignment: .leading, spacing: 2) {
                    Text(ranked.show.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.primary)
                        .lineLimit(2)
                    Text("\(ranked.reviewCount) \(ranked.reviewCount == 1 ? "rating" : "ratings") this month")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 0)

                RatingBadge(rating: ranked.averageRating)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var posterThumb: some View {
        Group {
            if let posterURL = ranked.show.posterURL {
                AsyncImageView(urlString: posterURL)
            } else {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.gray.opacity(0.2))
                    .overlay(
                        Image(systemName: ranked.show.category == .movie ? "film" : "tv")
                            .foregroundStyle(Color.secondary)
                    )
            }
        }
        .frame(width: 40, height: 60)
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}

#Preview {
    ActivityTabView()
        .environment(NebRatingsStore())
}
