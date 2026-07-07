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

    /// Friends' (and my own) events float above everyone else's.
    private var friendActivities: [Activity] {
        activities.filter { isFriendOrMe($0.userID) }
    }

    private var communityActivities: [Activity] {
        activities.filter { !isFriendOrMe($0.userID) }
    }

    var body: some View {
        List {
            if isLoading && activities.isEmpty {
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
                .listRowSeparator(.hidden)
            } else if activities.isEmpty {
                ContentUnavailableView(
                    "No activity yet",
                    systemImage: "sparkles",
                    description: Text("Ratings and list updates from the community will show up here.")
                )
            } else {
                if !friendActivities.isEmpty {
                    Section("Friends & You") {
                        ForEach(friendActivities) { activity in
                            ActivityRow(activity: activity, navigationPath: $navigationPath)
                        }
                    }
                }
                if !communityActivities.isEmpty {
                    Section("Community") {
                        ForEach(communityActivities) { activity in
                            ActivityRow(activity: activity, navigationPath: $navigationPath)
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .task {
            await load()
        }
        .refreshable {
            await load()
        }
    }

    private func isFriendOrMe(_ userID: String) -> Bool {
        userID == store.currentUser?.id || store.isFriend(userID)
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
                        Text(String(format: "🔥 %.1f", rating))
                            .font(.caption.bold())
                            .foregroundStyle(.purple)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.purple.opacity(0.12), in: Capsule())
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

#Preview {
    ActivityTabView()
        .environment(NebRatingsStore())
}
