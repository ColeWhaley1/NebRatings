//
//  WatchTogetherView.swift
//  NebRatings
//
//  Group recommendations: pick friends (and optionally a movies/TV filter),
//  generate titles the whole group is likely to enjoy — each with a
//  confidence score and "recommended because" bullets. Saving offers a
//  list picker, including creating a new list shared with the group.
//  Pushed from the Friends tab via WatchTogetherRoute (a 6th root tab
//  would overflow into iOS's "More" tab).
//

import SwiftUI
import UIKit

struct WatchTogetherView: View {
    @Environment(NebRatingsStore.self) private var store

    /// Accepted friends, resolved to profiles for the picker.
    @State private var friendProfiles: [UserProfile] = []
    @State private var selectedFriendIDs: Set<String> = []

    private enum Phase {
        case picking
        case loading
        case results
    }
    @State private var phase: Phase = .picking

    enum MediaFilter: String, CaseIterable, Identifiable {
        case all = "All"
        case movies = "Movies"
        case tv = "TV Shows"
        var id: String { rawValue }

        func matches(_ show: Show) -> Bool {
            switch self {
            case .all: return true
            case .movies: return show.category == .movie
            case .tv: return show.category == .series
            }
        }
    }
    @State private var mediaFilter: MediaFilter = .all

    /// Candidate pool from the last Generate — kept so the media filter
    /// re-scores instantly without refetching TMDB.
    @State private var candidates: [Show: Set<CandidateSource>] = [:]
    /// Full ranked list (top 30); `pageStart` rotates through it so
    /// Regenerate shows fresh picks without refetching everything.
    @State private var rankedPool: [GroupRecommendation] = []
    @State private var pageStart: Int = 0
    /// Where each media filter last was — switching Movies → TV → Movies
    /// returns to the regenerated slice, not the first one.
    @State private var pageStartByFilter: [MediaFilter: Int] = [:]
    @State private var members: [GroupMember] = []

    /// Share sheet payload.
    @State private var shareItems: [Any] = []
    @State private var isSharePresented = false
    /// Which recommendation is being saved (drives the list-picker sheet).
    @State private var savingRecommendation: GroupRecommendation?
    /// ids already saved this session (button feedback).
    @State private var savedShowIDs: Set<Int> = []

    private let pageSize = 6
    private var visibleRecommendations: [GroupRecommendation] {
        guard !rankedPool.isEmpty else { return [] }
        let end = min(pageStart + pageSize, rankedPool.count)
        return Array(rankedPool[pageStart..<end])
    }

    var body: some View {
        Group {
            switch phase {
            case .picking:
                pickerList
            case .loading:
                loadingView
            case .results:
                resultsList
            }
        }
        .navigationTitle("Watch Together")
        .navigationBarTitleDisplayMode(.inline)
        // One accent family everywhere in this feature — no blue/purple clash.
        .tint(.purple)
        .task {
            await loadFriends()
        }
        .sheet(isPresented: $isSharePresented) {
            ActivityShareSheet(items: shareItems)
        }
        .sheet(item: $savingRecommendation) { recommendation in
            SaveToListSheet(
                show: recommendation.show,
                groupFriendIDs: Array(selectedFriendIDs),
                groupNames: members.dropFirst().map(\.profile.username),
                onSaved: {
                    savedShowIDs.insert(recommendation.show.id)
                }
            )
            .environment(store)
        }
    }

    // MARK: - Phase 1: pick friends

    private var pickerList: some View {
        List {
            Section {
                if friendProfiles.isEmpty {
                    ContentUnavailableView(
                        "No friends yet",
                        systemImage: "person.2",
                        description: Text("Add friends from the Friends tab first — then find something to watch together.")
                    )
                } else {
                    ForEach(friendProfiles) { profile in
                        Button {
                            toggle(profile.id)
                        } label: {
                            HStack(spacing: 12) {
                                AvatarView(emoji: profile.avatarEmoji, size: 40)
                                // Concrete Color.primary: hierarchical
                                // .primary resolves against the button's
                                // tint here and rendered names purple.
                                Text(profile.username)
                                    .font(.body)
                                    .foregroundStyle(Color.primary)
                                Spacer()
                                Image(systemName: selectedFriendIDs.contains(profile.id) ? "checkmark.circle.fill" : "circle")
                                    .font(.title3)
                                    .foregroundStyle(selectedFriendIDs.contains(profile.id) ? .purple : .secondary)
                            }
                        }
                    }
                }
            } header: {
                Text("Who's watching?")
            } footer: {
                Text("Pick one or more friends. Recommendations blend everyone's ratings, genres, and watchlists.")
            }

            Section("Looking for") {
                Picker("Looking for", selection: $mediaFilter) {
                    ForEach(MediaFilter.allCases) { filter in
                        Text(filter.rawValue).tag(filter)
                    }
                }
                .pickerStyle(.segmented)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
            }

            Section {
                Button {
                    Task { await generate() }
                } label: {
                    HStack {
                        Spacer()
                        Label("Find Something to Watch", systemImage: "sparkles.tv")
                            .font(.headline)
                            // Monochrome + explicit white: this symbol is
                            // hierarchical, and its accent-tinted layers went
                            // purple-on-purple (invisible) once the button
                            // became enabled.
                            .symbolRenderingMode(.monochrome)
                            .foregroundStyle(selectedFriendIDs.isEmpty ? Color.secondary : Color.white)
                        Spacer()
                    }
                    .padding(.vertical, 6)
                }
                .buttonStyle(.borderedProminent)
                .disabled(selectedFriendIDs.isEmpty)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())
            }
        }
        .listStyle(.insetGrouped)
    }

    private func toggle(_ id: String) {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        if selectedFriendIDs.contains(id) {
            selectedFriendIDs.remove(id)
        } else {
            selectedFriendIDs.insert(id)
        }
    }

    // MARK: - Phase 2: loading

    private var loadingView: some View {
        VStack(spacing: 14) {
            ProgressView()
                .controlSize(.large)
            Text("Blending everyone's taste…")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Phase 3: results

    private var resultsList: some View {
        List {
            Section {
                groupHeader
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
                    .listRowSeparator(.hidden)

                Picker("Looking for", selection: $mediaFilter) {
                    ForEach(MediaFilter.allCases) { filter in
                        Text(filter.rawValue).tag(filter)
                    }
                }
                .pickerStyle(.segmented)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 4, trailing: 0))
                .listRowSeparator(.hidden)
                .onChange(of: mediaFilter) { _, _ in
                    // Re-rank the cached pool — no network needed.
                    applyEngine()
                }
            }

            Section {
                if visibleRecommendations.isEmpty {
                    ContentUnavailableView(
                        "Nothing fits… yet",
                        systemImage: "sparkles",
                        description: Text(mediaFilter == .all
                            ? "Rate more titles (and pick favorite genres) so the group engine has more to work with."
                            : "No \(mediaFilter.rawValue.lowercased()) matched — try All or regenerate.")
                    )
                } else {
                    ForEach(visibleRecommendations) { recommendation in
                        recommendationRow(recommendation)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button {
                    regenerate()
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .accessibilityLabel("Regenerate suggestions")

                Button {
                    prepareShare()
                } label: {
                    Image(systemName: "square.and.arrow.up")
                }
                .accessibilityLabel("Share suggestions")
                .disabled(visibleRecommendations.isEmpty)
            }
        }
    }

    private var groupHeader: some View {
        HStack(spacing: -10) {
            AvatarView(emoji: store.currentUser?.avatarEmoji, size: 40)
            ForEach(members.dropFirst()) { member in
                AvatarView(emoji: member.profile.avatarEmoji, size: 40)
            }
            Spacer().frame(width: 22)
            Text(groupNames)
                .font(.subheadline.bold())
                .lineLimit(2)
            Spacer()
            Button("Change") {
                phase = .picking
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(.purple)
        }
    }

    private var groupNames: String {
        let names = members.map(\.profile.username)
        if names.count <= 3 { return names.joined(separator: ", ") }
        return names.prefix(2).joined(separator: ", ") + " + \(names.count - 2) more"
    }

    private func recommendationRow(_ recommendation: GroupRecommendation) -> some View {
        NavigationLink(value: recommendation.show) {
            HStack(alignment: .top, spacing: 12) {
                Group {
                    if let posterURL = recommendation.show.posterURL {
                        AsyncImageView(urlString: posterURL)
                    } else {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.gray.opacity(0.2))
                            .overlay(Image(systemName: "film").foregroundStyle(.secondary))
                    }
                }
                .frame(width: 70, height: 105)
                .clipShape(RoundedRectangle(cornerRadius: 8))

                VStack(alignment: .leading, spacing: 6) {
                    HStack(alignment: .top) {
                        Text(recommendation.show.title)
                            .font(.subheadline.bold())
                            .lineLimit(2)
                        Spacer(minLength: 6)
                        Text("\(recommendation.confidence)% Match")
                            .font(.caption2.bold())
                            .foregroundStyle(.white)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(matchColor(recommendation.confidence), in: Capsule())
                    }

                    ForEach(recommendation.reasons, id: \.self) { reason in
                        HStack(alignment: .top, spacing: 5) {
                            Text("•")
                                .font(.caption)
                                .foregroundStyle(.purple)
                            Text(reason)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }

                    Button {
                        savingRecommendation = recommendation
                    } label: {
                        Label(
                            savedShowIDs.contains(recommendation.show.id) ? "Saved" : "Save to a list",
                            systemImage: savedShowIDs.contains(recommendation.show.id) ? "checkmark" : "plus.circle"
                        )
                        .font(.caption.bold())
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.mini)
                    // Explicit — inside a NavigationLink label the inherited
                    // tint sometimes lost to the default accent (blue plus).
                    .tint(.purple)
                    .disabled(savedShowIDs.contains(recommendation.show.id))
                }
            }
            .padding(.vertical, 4)
        }
    }

    /// Purple family only — the confidence tiers stay in-theme.
    private func matchColor(_ confidence: Int) -> Color {
        switch confidence {
        case 85...: return .purple
        case 70..<85: return .pink
        default: return .gray
        }
    }

    // MARK: - Actions

    private func loadFriends() async {
        guard friendProfiles.isEmpty, let me = store.currentUser?.id else { return }
        let friendIDs = store.friends.compactMap { $0.otherUserID(currentUserID: me) }
        friendProfiles = await store.fetchProfiles(userIDs: friendIDs)
            .sorted { $0.username.lowercased() < $1.username.lowercased() }
    }

    private func generate() async {
        phase = .loading
        members = await store.assembleGroupMembers(friendIDs: Array(selectedFriendIDs))
        candidates = await store.gatherGroupCandidates(members: members)
        pageStartByFilter = [:] // fresh session, forget old positions
        applyEngine()
        savedShowIDs = []
        phase = .results
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    /// Runs the (pure) engine over cached candidates with the media filter,
    /// restoring wherever this filter's rotation last stood.
    private func applyEngine() {
        let filtered = candidates.filter { mediaFilter.matches($0.key) }
        rankedPool = GroupRecommendationEngine.recommend(members: members, candidates: filtered, limit: 30)
        let remembered = pageStartByFilter[mediaFilter] ?? 0
        pageStart = remembered < rankedPool.count ? remembered : 0
    }

    /// Shows the next slice of the ranked pool (wraps around), remembering
    /// the position per media filter.
    private func regenerate() {
        guard !rankedPool.isEmpty else { return }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        withAnimation(.snappy) {
            pageStart = (pageStart + pageSize) >= rankedPool.count ? 0 : pageStart + pageSize
            pageStartByFilter[mediaFilter] = pageStart
        }
    }

    private func prepareShare() {
        let lines = ["Our Watch Together picks 🍿"]
            + visibleRecommendations.map { "• \($0.show.title) — \($0.confidence)% match" }
            + ["via NebRatings"]
        shareItems = [lines.joined(separator: "\n")]
        isSharePresented = true
    }
}

// MARK: - Save to list

/// List picker for saving a Watch Together pick: any list the user can
/// edit, or a brand-new list created as shared with the whole group
/// (friends added as contributors).
private struct SaveToListSheet: View {
    let show: Show
    let groupFriendIDs: [String]
    let groupNames: [String]
    let onSaved: () -> Void

    @Environment(NebRatingsStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var newListName: String = ""
    @State private var isSaving = false

    private var editableLists: [ShowList] {
        guard let me = store.currentUser?.id else { return [] }
        return store.showLists.filter { $0.canEdit(userID: me) }
    }

    var body: some View {
        NavigationStack {
            List {
                Section("Save “\(show.title)” to…") {
                    if editableLists.isEmpty {
                        Text("No lists yet — create one below.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    ForEach(editableLists) { list in
                        Button {
                            Task { await save(to: list.id, createShared: false) }
                        } label: {
                            HStack {
                                Image(systemName: list.isDefault ? "bookmark.fill" : "list.bullet.rectangle")
                                    .foregroundStyle(list.isDefault ? Color.purple : Color.secondary)
                                    .frame(width: 24)
                                VStack(alignment: .leading, spacing: 2) {
                                    // Concrete colors: hierarchical .primary /
                                    // .secondary resolve against the button
                                    // tint and rendered these purple.
                                    Text(list.name)
                                        .foregroundStyle(Color.primary)
                                    Text("\(list.showReferences.count) \(list.showReferences.count == 1 ? "item" : "items")")
                                        .font(.caption)
                                        .foregroundStyle(Color.secondary)
                                }
                                Spacer()
                                if list.contains(showID: show.id) {
                                    Text("Already in")
                                        .font(.caption)
                                        .foregroundStyle(Color.secondary)
                                }
                            }
                        }
                        .disabled(isSaving || list.contains(showID: show.id))
                    }
                }

                Section {
                    TextField("New list name", text: $newListName)
                        .autocapitalization(.words)
                    Button {
                        Task { await save(to: nil, createShared: true) }
                    } label: {
                        Label("Create shared list & save", systemImage: "person.2.badge.plus")
                            .font(.subheadline.weight(.semibold))
                    }
                    .disabled(isSaving || newListName.trimmingCharacters(in: .whitespaces).isEmpty)
                } header: {
                    Text("New shared list")
                } footer: {
                    Text(groupNames.isEmpty
                         ? "Creates a new list and saves this pick to it."
                         : "Creates a list shared with \(groupNames.joined(separator: ", ")) — everyone can add to it.")
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Save to List")
            .navigationBarTitleDisplayMode(.inline)
            .tint(.purple)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .disabled(isSaving)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    if isSaving { ProgressView() }
                }
            }
            .onAppear {
                if newListName.isEmpty {
                    newListName = suggestedListName
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private var suggestedListName: String {
        switch groupNames.count {
        case 0: return "Watch Together"
        case 1: return "Watch with \(groupNames[0])"
        default: return "Movie Night Crew"
        }
    }

    private func save(to listID: String?, createShared: Bool) async {
        isSaving = true
        var targetID = listID

        if createShared {
            let name = newListName.trimmingCharacters(in: .whitespaces)
            await store.createList(name: name)
            if let created = store.showLists.first(where: { $0.name == name }) {
                targetID = created.id
                for friendID in groupFriendIDs {
                    await store.addContributor(friendID, to: created.id)
                }
            }
        }

        guard let targetID else {
            isSaving = false
            return
        }
        await store.addShowToList(show, listID: targetID)
        onSaved()
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        isSaving = false
        dismiss()
    }
}

#Preview {
    NavigationStack {
        WatchTogetherView()
            .environment(NebRatingsStore())
    }
}
