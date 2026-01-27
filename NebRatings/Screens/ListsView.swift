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
    @State private var showingOwnerWarning = false
    @State private var listNotOwned: ShowList?
    
    private var showingDeleteAlert: Binding<Bool> {
        Binding(
            get: { listToDelete != nil },
            set: { if !$0 { listToDelete = nil } }
        )
    }
    
    private var currentUserID: String? {
        store.authService.getCurrentUserID()
    }
    
    private func isOwner(of list: ShowList) -> Bool {
        guard let userID = currentUserID else { return false }
        return list.ownerID == userID
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
                                    
                                    Text("\(list.showReferences.count) \(list.showReferences.count == 1 ? "item" : "items")")
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
                                // Check if user is the owner before allowing delete
                                if isOwner(of: list) {
                                    listToDelete = list
                                } else {
                                    listNotOwned = list
                                    showingOwnerWarning = true
                                }
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
            .alert("Cannot Delete List", isPresented: $showingOwnerWarning, presenting: listNotOwned) { list in
                Button("Yes", role: .destructive) {
                    Task {
                        await store.removeSelfAsContributor(from: list.id)
                        listNotOwned = nil
                    }
                }
                Button("No", role: .cancel) {
                    listNotOwned = nil
                }
            } message: { list in
                Text("You cannot delete \"\(list.name)\" because you are not the owner of this list. Would you like to remove yourself as a contributor?")
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
                        .autocapitalization(.none)
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
    @State private var isEditingName = false
    @State private var editedListName = ""
    @State private var isUpdatingName = false
    
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
            // List name editing section (only show when editing)
            if isEditingName {
                Section {
                    TextField("List Name", text: $editedListName)
                        .font(.headline)
                        .autocapitalization(.none)
                } header: {
                    Text("List Name")
                } footer: {
                    Text("Give your list a descriptive name to help organize your shows.")
                }
            }
            
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
            
            Section {
                if currentList.showReferences.isEmpty {
                    ContentUnavailableView(
                        "Empty List",
                        systemImage: "list.bullet.rectangle",
                        description: Text("Add shows to this list from the Discover tab.")
                    )
                } else {
                    ForEach(currentList.showReferences, id: \.id) { reference in
                        // Validate that the cached show's ID and category match the reference
                        if let show = store.showCache[reference.id], 
                           show.id == reference.id,
                           show.category == reference.category {
                            NavigationLink(value: show) {
                                ShowRow(show: show)
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button(role: .destructive) {
                                    Task { @MainActor in
                                        // Optimistically update local state for smooth animation
                                        if var updatedList = store.showLists.first(where: { $0.id == currentList.id }) {
                                            updatedList.showReferences.removeAll { $0.id == reference.id && $0.category == reference.category }
                                            currentList = updatedList
                                        }
                                        // Then sync with Firebase
                                        await store.removeShowFromList(show, listID: currentList.id)
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
                                        // Remove by reference
                                        if var updatedList = store.showLists.first(where: { $0.id == currentList.id }) {
                                            updatedList.showReferences.removeAll { $0.id == reference.id && $0.category == reference.category }
                                            // Update in Firebase
                                            if let userID = store.authService.getCurrentUserID() {
                                                try? await store.listService.updateList(updatedList, for: userID)
                                            }
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
                            let referencesToRemove = indexSet.compactMap { index in
                                index < currentList.showReferences.count ? currentList.showReferences[index] : nil
                            }
                            
                            // Remove references from local state
                            for reference in referencesToRemove {
                                updatedList.showReferences.removeAll { $0.id == reference.id && $0.category == reference.category }
                            }
                            currentList = updatedList
                            
                            // Then sync with Firebase - try to get Show objects from cache
                            for reference in referencesToRemove {
                                if let show = store.showCache[reference.id],
                                   show.id == reference.id,
                                   show.category == reference.category {
                                    await store.removeShowFromList(show, listID: currentList.id)
                                } else {
                                    // Fallback to ID-only removal if show not in cache
                                    await store.removeShowFromList(reference.id, listID: currentList.id)
                                }
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
        .navigationTitle(isEditingName ? "" : currentList.name)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            if isOwner {
                ToolbarItem(placement: .navigationBarTrailing) {
                    if isEditingName {
                        HStack {
                            if isUpdatingName {
                                ProgressView()
                                    .scaleEffect(0.8)
                            } else {
                                Button("Save") {
                                    Task {
                                        await saveListName()
                                    }
                                }
                                .disabled(editedListName.trimmingCharacters(in: .whitespaces).isEmpty || editedListName.trimmingCharacters(in: .whitespaces) == currentList.name)
                                
                                Button("Cancel") {
                                    cancelEdit()
                                }
                            }
                        }
                    } else {
                        Button {
                            startEditing()
                        } label: {
                            Image(systemName: "pencil")
                                .foregroundStyle(.primary)
                        }
                    }
                }
            }
        }
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
                // Only reload list data if not currently editing (to avoid disrupting edit flow)
                if !isEditingName {
                    Task {
                        await loadListData()
                    }
                }
            }
        }
        // Don't use onChange or onAppear - they can disrupt navigation
        // Instead, update explicitly when shows are added/removed via swipe actions
    }
    
    private func startEditing() {
        editedListName = currentList.name
        isEditingName = true
    }
    
    private func cancelEdit() {
        isEditingName = false
        editedListName = ""
        isUpdatingName = false
    }
    
    private func saveListName() async {
        let trimmedName = editedListName.trimmingCharacters(in: .whitespaces)
        guard !trimmedName.isEmpty else {
            cancelEdit()
            return
        }
        
        isUpdatingName = true
        await store.updateListName(currentList.id, newName: trimmedName)
        isUpdatingName = false
        cancelEdit()
        
        // Update currentList from store to reflect the change
        if let updatedList = store.showLists.first(where: { $0.id == currentList.id }) {
            currentList = updatedList
        }
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
        // Find shows that aren't in the cache or have wrong category
        let missingReferences = currentList.showReferences.filter { reference in
            guard let cached = store.showCache[reference.id] else {
                return true // Not in cache
            }
            // Also reload if category doesn't match (for backwards compatibility migration)
            return cached.category != reference.category
        }
        
        // Fetch all missing shows in parallel using their stored categories
        await withTaskGroup(of: Void.self) { group in
            for reference in missingReferences {
                group.addTask {
                    // Use the stored category from the reference
                    if let show = await self.store.fetchShowDetails(id: reference.id, category: reference.category) {
                        // Verify the fetched show's ID and category match
                        if show.id == reference.id && show.category == reference.category {
                            return // Success - correct show cached
                        }
                    }
                    
                    // If the stored category failed, try the other category (for backwards compatibility)
                    let otherCategory: Show.Category = reference.category == .movie ? .series : .movie
                    if let show = await self.store.fetchShowDetails(id: reference.id, category: otherCategory) {
                        // Verify the fetched show's ID matches
                        if show.id == reference.id {
                            // Update the reference with the correct category
                            await MainActor.run {
                                if let listIndex = self.store.showLists.firstIndex(where: { $0.id == self.currentList.id }) {
                                    var updatedList = self.store.showLists[listIndex]
                                    if let refIndex = updatedList.showReferences.firstIndex(where: { $0.id == reference.id }) {
                                        updatedList.showReferences[refIndex] = ShowReference(id: show.id, category: show.category)
                                        self.store.showLists[listIndex] = updatedList
                                        // Update in Firebase
                                        Task {
                                            if let userID = self.store.authService.getCurrentUserID() {
                                                try? await self.store.listService.updateList(updatedList, for: userID)
                                            }
                                        }
                                    }
                                }
                            }
                            return // Success - correct show cached with updated category
                        }
                    }
                    
                    // If both failed, skip it
                }
            }
        }
    }
}


