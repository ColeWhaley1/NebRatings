//
//  UserProfileView.swift
//  NebRatings
//
//  Read-only view of another user's profile. The current user's profile lives in
//  ProfileView, which adds edit affordances and reuses the same gauge / top-3 components.
//

import SwiftUI

struct UserProfileView: View {
    @Environment(NebRatingsStore.self) private var store: NebRatingsStore
    @Environment(\.dismiss) private var dismiss

    let userID: String
    /// Optional pre-loaded profile (saves a round-trip when navigating from search results).
    let initialProfile: UserProfile?

    @State private var profile: UserProfile?
    @State private var reviews: [Review] = []
    @State private var isLoadingReviews = true
    @State private var currentReviewPage: Int = 0
    /// Accepted-friend count; nil until loaded (or if the query fails — the
    /// stat tile hides in that case).
    @State private var friendCount: Int?
    /// This user's lists the current viewer may see (public + friends-only
    /// when the viewer is a friend).
    @State private var visibleLists: [ShowList] = []
    /// Drives navigation when a top-3 pick is tapped. We can't use
    /// `NavigationLink` inside TopThreePicks (multiple side-by-side links
    /// in a List row trigger a SwiftUI tap-bleed bug), so the closure sets
    /// this binding and `.navigationDestination(item:)` performs the push.
    @State private var pickDestination: Show?
    /// Pushes the taste-comparison screen.
    @State private var showingCompatibility = false
    /// Profile share sheet payload (nil = not presented).
    @State private var sharePayload: SharePayload?

    private let reviewsPerPage = 5

    init(userID: String, initialProfile: UserProfile? = nil) {
        self.userID = userID
        self.initialProfile = initialProfile
        _profile = State(initialValue: initialProfile)
    }

    // NOTE: This view is always pushed into an existing NavigationStack (FriendsView's),
    // so it must NOT create its own — a nested NavigationStack renders as a broken
    // placeholder. Navigation to show details is handled by NavigationLink values that
    // resolve against destinations registered on the parent stack.
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                headerSection
                // Bio, favorite genres/titles, join date.
                ProfileAboutSection(
                    profile: profile,
                    onOpenFavorite: { favorite in
                        Task {
                            if let show = await store.fetchShowDetailsByTMDBID(tmdbID: favorite.id, category: favorite.category) {
                                pickDestination = show
                            }
                        }
                    }
                )
                // Reads the persisted aggregate on the profile doc — no TMDB recompute on view.
                CriticGaugeView(
                    delta: profile?.criticDelta,
                    sampleSize: profile?.criticSampleSize ?? 0,
                    isLoading: profile == nil
                )
                TopGenreView(
                    genre: profile?.topGenre,
                    isLoading: profile == nil
                )
                TopThreePicks(reviews: reviews) { show in
                    pickDestination = show
                }
                ProfileStatsSection(
                    reviews: reviews,
                    publicListCount: visibleLists.isEmpty ? nil : visibleLists.count,
                    friendCount: friendCount,
                    onOpenHighlight: { review in
                        if let show = store.show(for: review) {
                            pickDestination = show
                        }
                    }
                )
                VisibleListsSection(lists: visibleLists)
                reviewsList
            }
            .padding(16)
        }
        .navigationTitle(profile?.username ?? "Profile")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if let profile {
                    Button {
                        Task {
                            sharePayload = SharePayload(items: await ShareService.items(for: .profile(profile)))
                        }
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                    }
                    .accessibilityLabel("Share \(profile.username)'s profile")
                }
            }
        }
        .sheet(item: $sharePayload) { payload in
            ActivityShareSheet(items: payload.items)
        }
        .navigationDestination(item: $pickDestination) { show in
            ShowDetailView(show: show)
        }
        .navigationDestination(isPresented: $showingCompatibility) {
            CompatibilityView(otherUserID: userID, otherProfile: profile)
        }
        .task { await load() }
        .refreshable { await load() }
    }

    private var headerSection: some View {
        VStack(spacing: 12) {
            AvatarView(emoji: profile?.avatarEmoji, size: 96)
            Text(profile?.username ?? "Loading…")
                .font(.title2.bold())
            friendActionRow

            // Taste comparison — only meaningful against someone else.
            if store.currentUser?.id != userID {
                Button {
                    showingCompatibility = true
                } label: {
                    Label("Compare Tastes", systemImage: "heart.text.square")
                        .font(.subheadline.weight(.medium))
                }
                .buttonStyle(.bordered)
                .tint(.purple)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 8)
    }

    @ViewBuilder
    private var friendActionRow: some View {
        if let me = store.currentUser?.id, me != userID {
            let state = store.relationshipState(with: userID)
            switch state {
            case .none:
                Button {
                    Task { await store.sendFriendRequest(to: userID) }
                } label: {
                    Label("Add Friend", systemImage: "person.crop.circle.badge.plus")
                }
                .buttonStyle(.borderedProminent)

            case .outgoingRequest:
                Button {
                    Task { await store.removeRelationship(with: userID) }
                } label: {
                    Label("Cancel Request", systemImage: "paperplane")
                }
                .buttonStyle(.bordered)

            case .incomingRequest:
                HStack(spacing: 10) {
                    Button {
                        Task { await store.acceptFriendRequest(from: userID) }
                    } label: {
                        Label("Accept", systemImage: "checkmark.circle.fill")
                    }
                    .buttonStyle(.borderedProminent)
                    Button {
                        Task { await store.removeRelationship(with: userID) }
                    } label: {
                        Label("Decline", systemImage: "xmark.circle")
                    }
                    .buttonStyle(.bordered)
                }

            case .friends:
                Menu {
                    Button("Remove Friend", role: .destructive) {
                        Task { await store.removeRelationship(with: userID) }
                    }
                } label: {
                    Label("Friends", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                }
                .buttonStyle(.bordered)
            }
        }
    }

    @ViewBuilder
    private var reviewsList: some View {
        let allReviews = sortedReviews
        let pageCount = ReviewPagination.pageCount(for: allReviews.count, pageSize: reviewsPerPage)

        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "text.bubble")
                    .foregroundStyle(.secondary)
                Text("Reviews")
                    .font(.subheadline.bold())
                    .foregroundStyle(.secondary)
                if !isLoadingReviews && !allReviews.isEmpty {
                    ReviewCountBadge(count: allReviews.count)
                }
                Spacer()
                if !isLoadingReviews {
                    ReviewPagerChevrons(
                        pageCount: pageCount,
                        currentPage: $currentReviewPage,
                        size: 28,
                        font: .subheadline
                    )
                }
            }

            if isLoadingReviews {
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
                .padding(.vertical, 30)
            } else if allReviews.isEmpty {
                ContentUnavailableView("No reviews yet", systemImage: "text.bubble")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
            } else {
                PaginatedReviewsCarousel(
                    reviews: allReviews,
                    pageSize: reviewsPerPage,
                    currentPage: $currentReviewPage
                ) { review in
                    if let show = store.show(for: review) {
                        NavigationLink(value: ShowWithContext(show: show, initialSeasonFilter: review.season)) {
                            ReviewCard(
                                review: review,
                                showTitle: show.title,
                                showCategory: show.category,
                                isOwnReview: store.currentUser?.id == userID,
                                authorAvatarEmoji: profile?.avatarEmoji,
                                isFriend: store.currentUser?.id != userID && store.isFriend(userID),
                                useLighterBackground: true,
                                currentUserID: store.currentUser?.id,
                                onReact: { emoji in
                                    Task { await store.setReaction(emoji: emoji, on: review) }
                                }
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var sortedReviews: [Review] {
        reviews.sorted { $0.timestamp > $1.timestamp }
    }

    private func load() async {
        // Always refetch the profile so the persisted critic aggregate is current.
        if let fresh = await store.fetchProfile(userID: userID) {
            profile = fresh
        }
        isLoadingReviews = true
        reviews = await store.fetchReviews(for: userID)
        isLoadingReviews = false
        // Social extras load after the primary content — each hides its
        // section when unavailable, so failures degrade quietly.
        friendCount = await store.fetchFriendCount(for: userID)
        visibleLists = await store.fetchVisibleLists(ownerID: userID)
    }
}
