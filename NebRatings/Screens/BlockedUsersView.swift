//
//  BlockedUsersView.swift
//  NebRatings
//
//  Manage the users the current account has blocked (App Store Guideline 1.2).
//  Reached from Settings → Privacy & Safety. Blocked users' reviews and
//  activity are hidden everywhere; unblocking from here restores their content.
//

import SwiftUI

struct BlockedUsersView: View {
    @Environment(NebRatingsStore.self) private var store

    /// Stable, sorted order so the list doesn't reshuffle as profiles load.
    private var blockedIDs: [String] { store.blockedUserIDs.sorted() }

    var body: some View {
        Group {
            if blockedIDs.isEmpty {
                ContentUnavailableView(
                    "No Blocked Users",
                    systemImage: "hand.raised.slash",
                    description: Text("People you block will appear here. You won't see their reviews or activity anywhere in the app.")
                )
            } else {
                List {
                    Section {
                        ForEach(blockedIDs, id: \.self) { id in
                            HStack(spacing: 12) {
                                AvatarView(emoji: store.cachedProfile(for: id)?.avatarEmoji, size: 36)
                                Text(store.cachedProfile(for: id)?.username ?? "Blocked user")
                                    .font(.body)
                                    .lineLimit(1)
                                Spacer()
                                Button("Unblock") {
                                    store.unblockUser(userID: id)
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                                .tint(.purple)
                            }
                            .swipeActions(edge: .trailing) {
                                Button("Unblock") {
                                    store.unblockUser(userID: id)
                                }
                                .tint(.purple)
                            }
                        }
                    } footer: {
                        Text("Unblocking restores a user's reviews and activity in your feeds.")
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
        .navigationTitle("Blocked Users")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            // Resolve usernames/avatars for blocked IDs that aren't cached yet.
            await store.ensureProfilesLoaded(forAuthorIDs: Array(store.blockedUserIDs))
        }
    }
}

#Preview {
    NavigationStack {
        BlockedUsersView()
            .environment(NebRatingsStore())
    }
}
