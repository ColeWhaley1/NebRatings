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
                        createList()
                    }
                    .disabled(newListName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .presentationDetents([.medium])
    }
    
    private func createList() {
        let trimmedName = newListName.trimmingCharacters(in: .whitespaces)
        guard !trimmedName.isEmpty else { return }
        
        Task {
            await store.createList(name: trimmedName)
        }
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
    
    init(list: ShowList) {
        self.list = list
        // Initialize with the passed list
        self._currentList = State(initialValue: list)
    }
    
    var body: some View {
        List {
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
        .task {
            // Sync with store when view first appears (only once)
            guard !hasLoaded else { return }
            hasLoaded = true
            if let updatedList = store.showLists.first(where: { $0.id == list.id }) {
                currentList = updatedList
            }
            
            // Fetch any missing shows from the list
            await loadMissingShows()
        }
        // Don't use onChange or onAppear - they can disrupt navigation
        // Instead, update explicitly when shows are added/removed via swipe actions
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


