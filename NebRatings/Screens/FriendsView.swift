//
//  FriendsView.swift
//  NebRatings
//

import SwiftUI

struct FriendsView: View {
    @Environment(NebRatingsStore.self) private var store: NebRatingsStore

    @State private var searchText = ""
    @State private var searchResults: [UserProfile] = []
    @State private var searchTask: Task<Void, Never>?
    @State private var isSearching = false
    @State private var friendProfiles: [String: UserProfile] = [:]
    @State private var navigationPath = NavigationPath()

    var body: some View {
        NavigationStack(path: $navigationPath) {
            List {
                if !searchText.isEmpty {
                    searchResultsSection
                } else {
                    if !store.incomingRequests.isEmpty {
                        requestsSection
                    }
                    friendsSection
                    if !store.outgoingRequests.isEmpty {
                        outgoingSection
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Friends")
            .searchable(text: $searchText, prompt: "Search by username")
            .navigationDestination(for: UserProfileDestination.self) { dest in
                UserProfileView(userID: dest.userID, initialProfile: dest.profile)
            }
            .onChange(of: searchText) { _, newValue in
                runSearch(newValue)
            }
            .task {
                await store.loadRelationships()
                await refreshFriendProfiles()
            }
            .refreshable {
                await store.loadRelationships()
                await refreshFriendProfiles()
            }
            .onChange(of: store.relationships) { _, _ in
                Task { await refreshFriendProfiles() }
            }
        }
    }

    // MARK: - Sections

    private var requestsSection: some View {
        Section {
            ForEach(store.incomingRequests, id: \.id) { rel in
                if let otherID = rel.otherUserID(currentUserID: store.currentUser?.id ?? ""),
                   let profile = friendProfiles[otherID] {
                    requestRow(profile: profile)
                }
            }
        } header: {
            Label("Friend Requests", systemImage: "person.crop.circle.badge.plus")
        }
    }

    private var friendsSection: some View {
        Section {
            if store.friends.isEmpty {
                ContentUnavailableView(
                    "No friends yet",
                    systemImage: "person.2",
                    description: Text("Search for a username above to send a friend request.")
                )
                .listRowBackground(Color.clear)
            } else {
                ForEach(store.friends, id: \.id) { rel in
                    if let otherID = rel.otherUserID(currentUserID: store.currentUser?.id ?? ""),
                       let profile = friendProfiles[otherID] {
                        friendRow(profile: profile)
                    }
                }
                .onDelete { offsets in
                    let me = store.currentUser?.id ?? ""
                    let targets = offsets.compactMap { store.friends[$0].otherUserID(currentUserID: me) }
                    Task {
                        for id in targets { await store.removeRelationship(with: id) }
                    }
                }
            }
        } header: {
            Label("Friends", systemImage: "person.2.fill")
        }
    }

    private var outgoingSection: some View {
        Section {
            ForEach(store.outgoingRequests, id: \.id) { rel in
                if let otherID = rel.otherUserID(currentUserID: store.currentUser?.id ?? ""),
                   let profile = friendProfiles[otherID] {
                    outgoingRow(profile: profile)
                }
            }
        } header: {
            Label("Pending", systemImage: "paperplane")
        }
    }

    private var searchResultsSection: some View {
        Section {
            if isSearching {
                HStack { Spacer(); ProgressView(); Spacer() }
            } else if filteredSearchResults.isEmpty {
                ContentUnavailableView("No users found", systemImage: "magnifyingglass")
                    .listRowBackground(Color.clear)
            } else {
                ForEach(filteredSearchResults) { profile in
                    searchRow(profile: profile)
                }
            }
        } header: {
            Label("Results", systemImage: "magnifyingglass")
        }
    }

    private var filteredSearchResults: [UserProfile] {
        let myID = store.currentUser?.id
        return searchResults.filter { $0.id != myID }
    }

    // MARK: - Rows

    private func friendRow(profile: UserProfile) -> some View {
        Button {
            navigationPath.append(UserProfileDestination(userID: profile.id, profile: profile))
        } label: {
            HStack(spacing: 12) {
                AvatarView(emoji: profile.avatarEmoji, photoURL: profile.avatarPhotoURL, size: 44)
                Text(profile.username)
                    .font(.body)
                    .foregroundStyle(.primary)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .buttonStyle(.plain)
    }

    private func requestRow(profile: UserProfile) -> some View {
        HStack(spacing: 12) {
            Button {
                navigationPath.append(UserProfileDestination(userID: profile.id, profile: profile))
            } label: {
                HStack(spacing: 12) {
                    AvatarView(emoji: profile.avatarEmoji, photoURL: profile.avatarPhotoURL, size: 44)
                    Text(profile.username)
                        .foregroundStyle(.primary)
                }
            }
            .buttonStyle(.plain)

            Spacer()

            Button {
                Task { await store.acceptFriendRequest(from: profile.id) }
            } label: {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.green)
            }
            .buttonStyle(.plain)

            Button {
                Task { await store.removeRelationship(with: profile.id) }
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
    }

    private func outgoingRow(profile: UserProfile) -> some View {
        HStack(spacing: 12) {
            AvatarView(emoji: profile.avatarEmoji, photoURL: profile.avatarPhotoURL, size: 44)
            Text(profile.username)
            Spacer()
            Text("Pending")
                .font(.caption)
                .foregroundStyle(.secondary)
            Button("Cancel") {
                Task { await store.removeRelationship(with: profile.id) }
            }
            .font(.caption)
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .padding(.vertical, 4)
    }

    private func searchRow(profile: UserProfile) -> some View {
        let state = store.relationshipState(with: profile.id)
        return HStack(spacing: 12) {
            Button {
                navigationPath.append(UserProfileDestination(userID: profile.id, profile: profile))
            } label: {
                HStack(spacing: 12) {
                    AvatarView(emoji: profile.avatarEmoji, photoURL: profile.avatarPhotoURL, size: 44)
                    Text(profile.username).foregroundStyle(.primary)
                }
            }
            .buttonStyle(.plain)

            Spacer()
            actionButton(for: profile, state: state)
        }
    }

    @ViewBuilder
    private func actionButton(for profile: UserProfile, state: RelationshipState) -> some View {
        switch state {
        case .none:
            Button {
                Task { await store.sendFriendRequest(to: profile.id) }
            } label: {
                Label("Add", systemImage: "person.crop.circle.badge.plus")
                    .labelStyle(.titleAndIcon)
                    .font(.caption.bold())
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)

        case .outgoingRequest:
            Text("Requested")
                .font(.caption)
                .foregroundStyle(.secondary)

        case .incomingRequest:
            Button("Accept") {
                Task { await store.acceptFriendRequest(from: profile.id) }
            }
            .font(.caption.bold())
            .buttonStyle(.borderedProminent)
            .controlSize(.small)

        case .friends:
            Label("Friends", systemImage: "checkmark.circle.fill")
                .font(.caption)
                .foregroundStyle(.green)
        }
    }

    // MARK: - Helpers

    private func runSearch(_ text: String) {
        searchTask?.cancel()
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else {
            searchResults = []
            isSearching = false
            return
        }
        isSearching = true
        searchTask = Task {
            try? await Task.sleep(nanoseconds: 250_000_000)
            guard !Task.isCancelled else { return }
            let results = await store.searchUsers(byName: trimmed)
            guard !Task.isCancelled else { return }
            searchResults = results
            isSearching = false
        }
    }

    private func refreshFriendProfiles() async {
        let me = store.currentUser?.id ?? ""
        let needed = Set(store.relationships.compactMap { $0.otherUserID(currentUserID: me) })
        let missing = needed.subtracting(friendProfiles.keys)
        guard !missing.isEmpty else {
            // Prune dropped relationships
            friendProfiles = friendProfiles.filter { needed.contains($0.key) }
            return
        }
        let fetched = await store.fetchProfiles(userIDs: Array(missing))
        for profile in fetched {
            friendProfiles[profile.id] = profile
        }
        friendProfiles = friendProfiles.filter { needed.contains($0.key) }
    }
}

struct UserProfileDestination: Hashable {
    let userID: String
    let profile: UserProfile?
}
