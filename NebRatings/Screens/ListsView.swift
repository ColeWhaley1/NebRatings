//
//  ListsView.swift
//  NebRatings
//
//  Created by Cole Whaley on 11/29/25.
//

import SwiftUI

struct ListsView: View {
    @Environment(NebRatingsStore.self) private var store: NebRatingsStore
    @State private var showingCreateList = false
    @State private var newListName = ""
    @State private var listToDelete: ShowList?
    
    private var showingDeleteAlert: Binding<Bool> {
        Binding(
            get: { listToDelete != nil },
            set: { if !$0 { listToDelete = nil } }
        )
    }
    
    var body: some View {
        NavigationStack {
            List {
                if store.showLists.isEmpty {
                    Section {
                        ContentUnavailableView(
                            "No lists yet",
                            systemImage: "list.bullet.rectangle",
                            description: Text("Create your first list to organize your favorite shows.")
                        )
                    }
                } else {
                    ForEach(store.showLists, id: \.id) { list in
                        NavigationLink(value: list) {
                            HStack {
                                Image(systemName: list.isDefault ? "bookmark.fill" : "list.bullet.rectangle")
                                    .foregroundStyle(list.isDefault ? .purple : .secondary)
                                    .frame(width: 24)
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(list.name)
                                        .font(.headline)
                                    
                                    Text("\(list.showIDs.count) \(list.showIDs.count == 1 ? "item" : "items")")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                                
                                Spacer()
                            }
                            .padding(.vertical, 4)
                        }
                    }
                    .onDelete { indexSet in
                        if let index = indexSet.first, index < store.showLists.count {
                            let list = store.showLists[index]
                            if !list.isDefault {
                                listToDelete = list
                            }
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Lists")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingCreateList = true
                    } label: {
                        Image(systemName: "plus")
                            .foregroundStyle(.primary)
                    }
                }
            }
            .sheet(isPresented: $showingCreateList) {
                createListSheet
            }
            .alert("Delete List", isPresented: showingDeleteAlert, presenting: listToDelete) { list in
                Button("Delete", role: .destructive) {
                    Task {
                        await store.deleteList(list)
                        listToDelete = nil
                    }
                }
                Button("Cancel", role: .cancel) {
                    listToDelete = nil
                }
            } message: { list in
                Text("Are you sure you want to delete \"\(list.name)\"? This action cannot be undone.")
            }
            .navigationDestination(for: ShowList.self) { list in
                ListDetailView(list: list)
                    .environment(store)
            }
            .task {
                // Only load lists if empty to avoid unnecessary updates
                if store.showLists.isEmpty {
                    await store.loadUserLists()
                }
            }
        }
    }
    
    private var createListSheet: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("List Name", text: $newListName)
                        .autocapitalization(.words)
                } header: {
                    Text("List Name")
                } footer: {
                    Text("Give your list a descriptive name to help organize your shows.")
                }
            }
            .navigationTitle("New List")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        showingCreateList = false
                        newListName = ""
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        Task {
                            await createList()
                        }
                    }
                    .disabled(newListName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .presentationDetents([.medium])
    }
    
    private func createList() async {
        let trimmedName = newListName.trimmingCharacters(in: .whitespaces)
        guard !trimmedName.isEmpty else { return }
        
        await store.createList(name: trimmedName)
        showingCreateList = false
        newListName = ""
    }
    
}

// Placeholder view for list detail - will be implemented later
struct ListDetailView: View {
    let list: ShowList
    @Environment(NebRatingsStore.self) private var store
    
    // Get the current list from the store to keep it in sync, but use @State to maintain stable reference
    @State private var currentList: ShowList
    @State private var hasLoaded = false
    @State private var showingAddContributor = false
    @State private var searchText = ""
    @State private var searchResults: [UserProfile] = []
    @State private var isSearching = false
    @State private var ownerProfile: UserProfile?
    @State private var contributorProfiles: [String: UserProfile] = [:]
    @State private var searchTask: Task<Void, Never>?
    
    private var currentUserID: String? {
        store.authService.getCurrentUserID()
    }
    
    private var isOwner: Bool {
        guard let userID = currentUserID else { return false }
        return currentList.ownerID == userID
    }
    
    init(list: ShowList) {
        self.list = list
        // Initialize with the passed list
        self._currentList = State(initialValue: list)
    }
    
    var body: some View {
        List {
            // Collaborators section (show to both owners and contributors)
            Section("Collaborators") {
                    // Owner
                    if let owner = ownerProfile {
                        HStack {
                            Image(systemName: "crown.fill")
                                .foregroundStyle(.yellow)
                                .frame(width: 24)
                            Text(owner.username)
                                .font(.body)
                            Spacer()
                            Text("Owner")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    
                    // Contributors
                    if currentList.contributorIDs.isEmpty {
                        Text("No contributors yet")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(currentList.contributorIDs, id: \.self) { contributorID in
                            if let contributor = contributorProfiles[contributorID] {
                                HStack {
                                    Image(systemName: "person.fill")
                                        .foregroundStyle(.secondary)
                                        .frame(width: 24)
                                    Text(contributor.username)
                                        .font(.body)
                                    Spacer()
                                }
                                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                    // Only owners can remove contributors
                                    if isOwner {
                                        Button(role: .destructive) {
                                            Task {
                                                await store.removeContributor(contributorID, from: currentList.id)
                                                await loadListData()
                                            }
                                        } label: {
                                            Label("Remove", systemImage: "trash")
                                        }
                                    }
                                }
                            } else {
                                HStack {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                    Text("Loading...")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                    
                    // Only owners can add contributors
                    if isOwner {
                        Button {
                            showingAddContributor = true
                        } label: {
                            Label("Add Contributor", systemImage: "person.badge.plus")
                                .foregroundStyle(.purple)
                        }
                    }
                }
            }
            
            Section {
                if currentList.showIDs.isEmpty {
                    ContentUnavailableView(
                        "Empty List",
                        systemImage: "list.bullet.rectangle",
                        description: Text("Add shows to this list from the Discover tab.")
                    )
                } else {
                    ForEach(currentList.showIDs, id: \.self) { showID in
                        if let show = store.showCache[showID] {
                            NavigationLink(value: show) {
                                ShowRow(show: show)
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button(role: .destructive) {
                                    Task { @MainActor in
                                        // Optimistically update local state for smooth animation
                                        if var updatedList = store.showLists.first(where: { $0.id == currentList.id }) {
                                            updatedList.showIDs.removeAll { $0 == showID }
                                            currentList = updatedList
                                        }
                                        // Then sync with Firebase
                                        await store.removeShowFromList(showID, listID: currentList.id)
                                        // Final sync with store
                                        if let finalList = store.showLists.first(where: { $0.id == currentList.id }) {
                                            currentList = finalList
                                        }
                                    }
                                } label: {
                                    Label("Remove", systemImage: "trash")
                                }
                            }
                        } else {
                            // Placeholder for shows not yet loaded - show loading state
                            HStack {
                                ProgressView()
                                    .scaleEffect(0.8)
                                Text("Loading show...")
                                    .foregroundStyle(.secondary)
                                Spacer()
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button(role: .destructive) {
                                    Task {
                                        await store.removeShowFromList(showID, listID: currentList.id)
                                        // Update local state after removal
                                        if let updatedList = store.showLists.first(where: { $0.id == currentList.id }) {
                                            currentList = updatedList
                                        }
                                    }
                                } label: {
                                    Label("Remove", systemImage: "trash")
                                }
                            }
                        }
                    }
                    .onDelete { indexSet in
                        Task { @MainActor in
                            // Optimistically update local state for smooth animation
                            var updatedList = currentList
                            let showIDsToRemove = indexSet.compactMap { index in
                                index < currentList.showIDs.count ? currentList.showIDs[index] : nil
                            }
                            updatedList.showIDs.removeAll { showIDsToRemove.contains($0) }
                            currentList = updatedList
                            
                            // Then sync with Firebase
                            for showID in showIDsToRemove {
                                await store.removeShowFromList(showID, listID: currentList.id)
                            }
                            
                            // Final sync with store
                            if let finalList = store.showLists.first(where: { $0.id == currentList.id }) {
                                currentList = finalList
                            }
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(currentList.name)
        .navigationBarTitleDisplayMode(.large)
        .navigationDestination(for: Show.self) { show in
            ShowDetailView(show: show)
        }
        .sheet(isPresented: $showingAddContributor) {
            addContributorSheet
        }
        .task {
            // Sync with store when view first appears (only once)
            guard !hasLoaded else { return }
            hasLoaded = true
            if let updatedList = store.showLists.first(where: { $0.id == list.id }) {
                currentList = updatedList
            }
            
            // Fetch any missing shows from the list
            await loadMissingShows()
            await loadListData()
        }
        .onChange(of: store.showLists) { _, _ in
            // Update current list when store changes
            if let updatedList = store.showLists.first(where: { $0.id == list.id }) {
                currentList = updatedList
                Task {
                    await loadListData()
                }
            }
        }
        // Don't use onChange or onAppear - they can disrupt navigation
        // Instead, update explicitly when shows are added/removed via swipe actions
    }
    
    private func loadListData() async {
        // Load owner profile
        if let owner = await store.fetchProfile(userID: currentList.ownerID) {
            ownerProfile = owner
        }
        
        // Load contributor profiles
        var profiles: [String: UserProfile] = [:]
        for contributorID in currentList.contributorIDs {
            if let profile = await store.fetchProfile(userID: contributorID) {
                profiles[contributorID] = profile
            }
        }
        contributorProfiles = profiles
    }
    
    private var addContributorSheet: some View {
        NavigationStack {
            List {
                Section {
                    TextField("Search by username", text: $searchText)
                        .autocapitalization(.none)
                        .autocorrectionDisabled()
                } header: {
                    Text("Search Users")
                } footer: {
                    Text("Search for users by username to add them as contributors.")
                }
                
                if isSearching {
                    Section {
                        HStack {
                            Spacer()
                            ProgressView()
                            Spacer()
                        }
                    }
                } else if !searchResults.isEmpty {
                    Section("Results") {
                        ForEach(searchResults) { user in
                            let isAlreadyContributor = currentList.contributorIDs.contains(user.id)
                            let isOwner = currentList.ownerID == user.id
                            let isCurrentUser = currentUserID == user.id
                            
                            HStack {
                                Text(user.username)
                                    .font(.body)
                                Spacer()
                                
                                if isOwner {
                                    Text("Owner")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                } else if isAlreadyContributor {
                                    Text("Contributor")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                } else if isCurrentUser {
                                    Text("You")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                } else {
                                    Button {
                                        Task {
                                            await store.addContributor(user.id, to: currentList.id)
                                            await loadListData()
                                            showingAddContributor = false
                                            searchText = ""
                                            searchResults = []
                                        }
                                    } label: {
                                        Text("Add")
                                            .foregroundStyle(.purple)
                                    }
                                }
                            }
                            .disabled(isOwner || isAlreadyContributor || isCurrentUser)
                        }
                    }
                } else if !searchText.isEmpty && !isSearching {
                    Section {
                        Text("No users found")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Add Contributor")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        showingAddContributor = false
                        searchText = ""
                        searchResults = []
                    }
                }
            }
            .onChange(of: searchText) { oldValue, newValue in
                performUserSearch()
            }
        }
        .presentationDetents([.medium, .large])
    }
    
    private func performUserSearch() {
        // Cancel previous search
        searchTask?.cancel()
        
        let trimmedSearch = searchText.trimmingCharacters(in: .whitespaces)
        
        guard !trimmedSearch.isEmpty else {
            searchResults = []
            isSearching = false
            return
        }
        
        isSearching = true
        
        searchTask = Task {
            // Debounce search
            try? await Task.sleep(nanoseconds: 300_000_000) // 0.3 seconds
            
            guard !Task.isCancelled else { return }
            
            let results = await store.searchUsers(byName: trimmedSearch)
            
            guard !Task.isCancelled else { return }
            
            // Filter out owner, current user, and existing contributors
            let filteredResults = results.filter { user in
                user.id != currentList.ownerID &&
                user.id != currentUserID &&
                !currentList.contributorIDs.contains(user.id)
            }
            
            searchResults = filteredResults
            isSearching = false
        }
    }
    
    private func loadMissingShows() async {
        // Find shows that aren't in the cache
        let missingShowIDs = currentList.showIDs.filter { store.showCache[$0] == nil }
        
        // Fetch all missing shows in parallel
        await withTaskGroup(of: Void.self) { group in
            for showID in missingShowIDs {
                group.addTask {
                    // Try fetching as a movie first
                    if await self.store.fetchShowDetails(id: showID, category: .movie) != nil {
                        return // Success
                    }
                    
                    // If movie failed, try as a series
                    if await self.store.fetchShowDetails(id: showID, category: .series) != nil {
                        return // Success
                    }
                    
                    // If both failed, log it
                    print("⚠️ Could not fetch show with ID: \(showID)")
                }
            }
        }
    }
}


