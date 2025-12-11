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
                    ForEach(store.showLists) { list in
                        NavigationLink {
                            // TODO: List detail view
                            ListDetailView(list: list)
                                .environment(store)
                        } label: {
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
            .task {
                await store.loadUserLists()
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
    
    // Get the current list from the store to keep it in sync
    private var currentList: ShowList? {
        store.showLists.first { $0.id == list.id }
    }
    
    // Use the current list if available, otherwise fall back to the passed list
    private var displayList: ShowList {
        currentList ?? list
    }
    
    var body: some View {
        List {
            Section {
                if displayList.showIDs.isEmpty {
                    ContentUnavailableView(
                        "Empty List",
                        systemImage: "list.bullet.rectangle",
                        description: Text("Add shows to this list from the Discover tab.")
                    )
                } else {
                    ForEach(displayList.showIDs, id: \.self) { showID in
                        if let show = store.showCache[showID] {
                            NavigationLink(value: show) {
                                ShowRow(show: show)
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button(role: .destructive) {
                                    Task {
                                        await store.removeShowFromList(showID, listID: displayList.id)
                                    }
                                } label: {
                                    Label("Remove", systemImage: "trash")
                                }
                            }
                        } else {
                            // Placeholder for shows not yet loaded
                            HStack {
                                Text("Show ID: \(showID)")
                                    .foregroundStyle(.secondary)
                                Spacer()
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button(role: .destructive) {
                                    Task {
                                        await store.removeShowFromList(showID, listID: displayList.id)
                                    }
                                } label: {
                                    Label("Remove", systemImage: "trash")
                                }
                            }
                        }
                    }
                    .onDelete { indexSet in
                        for index in indexSet {
                            if index < displayList.showIDs.count {
                                let showID = displayList.showIDs[index]
                                Task {
                                    await store.removeShowFromList(showID, listID: displayList.id)
                                }
                            }
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(displayList.name)
        .navigationBarTitleDisplayMode(.large)
        .navigationDestination(for: Show.self) { show in
            ShowDetailView(show: show)
        }
        .task {
            await store.loadUserLists()
        }
    }
}


