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
    @State private var criticDelta: Double?
    @State private var criticSampleSize: Int = 0
    @State private var isLoadingGauge = true
    @State private var navigationPath = NavigationPath()

    init(userID: String, initialProfile: UserProfile? = nil) {
        self.userID = userID
        self.initialProfile = initialProfile
        _profile = State(initialValue: initialProfile)
    }

    var body: some View {
        NavigationStack(path: $navigationPath) {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    headerSection
                    CriticGaugeView(delta: criticDelta, sampleSize: criticSampleSize, isLoading: isLoadingGauge)
                    TopThreePicks(reviews: reviews) { show in
                        navigationPath.append(show)
                    }
                    reviewsList
                }
                .padding(16)
            }
            .navigationTitle(profile?.username ?? "Profile")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(for: Show.self) { show in
                ShowDetailView(show: show)
            }
            .navigationDestination(for: ShowWithContext.self) { ctx in
                ShowDetailView(show: ctx.show, initialSeasonFilter: ctx.initialSeasonFilter)
            }
            .task { await load() }
            .refreshable { await load() }
        }
    }

    private var headerSection: some View {
        VStack(spacing: 12) {
            AvatarView(emoji: profile?.avatarEmoji, photoURL: profile?.avatarPhotoURL, size: 96)
            Text(profile?.username ?? "Loading…")
                .font(.title2.bold())
            friendActionRow
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
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "text.bubble")
                    .foregroundStyle(.secondary)
                Text("Reviews")
                    .font(.subheadline.bold())
                    .foregroundStyle(.secondary)
                Spacer()
                if !isLoadingReviews {
                    Text("\(reviews.count)")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }

            if isLoadingReviews {
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
                .padding(.vertical, 30)
            } else if reviews.isEmpty {
                ContentUnavailableView("No reviews yet", systemImage: "text.bubble")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
            } else {
                LazyVStack(spacing: 10) {
                    ForEach(sortedReviews) { review in
                        let show = store.show(for: review)
                        if let show {
                            ReviewCard(
                                review: review,
                                showTitle: show.title,
                                showCategory: show.category,
                                isOwnReview: store.currentUser?.id == userID,
                                onTap: {
                                    navigationPath.append(ShowWithContext(show: show, initialSeasonFilter: review.season))
                                },
                                useLighterBackground: true
                            )
                        }
                    }
                }
            }
        }
    }

    private var sortedReviews: [Review] {
        reviews.sorted { $0.timestamp > $1.timestamp }
    }

    private func load() async {
        if profile == nil {
            profile = await store.fetchProfile(userID: userID)
        }
        isLoadingReviews = true
        let fetched = await store.fetchReviews(for: userID)
        reviews = fetched
        isLoadingReviews = false

        isLoadingGauge = true
        if let result = await store.computeCriticDelta(reviews: fetched) {
            criticDelta = result.delta
            criticSampleSize = result.sampleSize
        } else {
            criticDelta = nil
            criticSampleSize = 0
        }
        isLoadingGauge = false
    }
}
