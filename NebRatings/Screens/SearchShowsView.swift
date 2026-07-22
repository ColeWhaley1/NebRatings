//
//  SearchShowsView.swift
//  NebRatings
//
//  Created by Cole Whaley on 11/29/25.
//

import SwiftUI

struct SearchShowsView: View {
    @Environment(NebRatingsStore.self) private var store: NebRatingsStore
    @State private var searchText = ""
    @State private var isSearchPresented = false
    @State private var selectedCategory: Show.Category? = nil
    @State private var searchTask: Task<Void, Never>?

    var body: some View {
        NavigationStack {
            Group {
                if isSearchPresented && searchText.isEmpty {
                    // Search field is focused but empty: offer recent searches.
                    RecentSearchesView(
                        recents: store.recentSearches,
                        onSelect: runSearch,
                        onRemove: { store.removeRecentSearch($0) },
                        onClear: { store.clearRecentSearches() }
                    )
                } else if searchText.isEmpty {
                    // Browse mode: moods + curated sections.
                    DiscoverHomeView()
                } else {
                    // Search mode: category filter + results.
                    VStack(spacing: 0) {
                        categoryFilterView

                        Group {
                            if store.isSearchingShows {
                                ProgressView("Searching...")
                                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                            } else if store.shows.isEmpty {
                                ContentUnavailableView("No results", systemImage: "magnifyingglass", description: Text("Try a different search term."))
                            } else {
                                List(store.shows) { show in
                                    NavigationLink(value: show) {
                                        ShowRow(show: show)
                                    }
                                    // Opening a result means this query mattered —
                                    // remember it. `recordSearch` de-dupes.
                                    .simultaneousGesture(TapGesture().onEnded {
                                        store.recordSearch(searchText)
                                    })
                                }
                                .listStyle(.insetGrouped)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Discover")
            .searchable(text: $searchText, isPresented: $isSearchPresented, prompt: "Search movies or TV shows")
            .onChange(of: searchText) { oldValue, newValue in
                if !newValue.isEmpty {
                    performSearch()
                }
            }
            .onChange(of: selectedCategory) { oldValue, newValue in
                if !searchText.isEmpty {
                    performSearch()
                }
            }
            .onSubmit(of: .search) {
                // Return key: the user committed to this query.
                store.recordSearch(searchText)
            }
            .navigationDestination(for: Show.self) { show in
                ShowDetailView(show: show)
            }
            .navigationDestination(for: Mood.self) { mood in
                MoodResultsView(mood: mood)
            }
            .navigationDestination(for: SeasonalCollection.self) { collection in
                SeasonalResultsView(collection: collection)
            }
        }
    }

    /// Runs one of the recent searches: fills the field (which kicks off the
    /// debounced search via `onChange`) and re-records it so it jumps to the
    /// top of the list.
    private func runSearch(_ query: String) {
        searchText = query
        store.recordSearch(query)
    }
    
    private var categoryFilterView: some View {
        Picker("Category", selection: $selectedCategory) {
            Text("All").tag(nil as Show.Category?)
            Text("Movies").tag(Show.Category.movie as Show.Category?)
            Text("TV Shows").tag(Show.Category.series as Show.Category?)
        }
        .pickerStyle(.segmented)
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(.systemGroupedBackground))
    }
    
    private func performSearch() {
        // Cancel previous search task
        searchTask?.cancel()

        // Debounce search - wait 0.5 seconds after user stops typing
        searchTask = Task {
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds

            guard !Task.isCancelled else { return }
            await store.searchShows(query: searchText, category: selectedCategory)
        }
    }
}

/// Recent-search list shown when the search field is focused but empty. Tap a
/// row to re-run it, swipe to delete one, or Clear to wipe the list.
private struct RecentSearchesView: View {
    let recents: [String]
    let onSelect: (String) -> Void
    let onRemove: (String) -> Void
    let onClear: () -> Void

    var body: some View {
        if recents.isEmpty {
            ContentUnavailableView(
                "No recent searches",
                systemImage: "clock.arrow.circlepath",
                description: Text("Movies and shows you search for will show up here.")
            )
        } else {
            List {
                Section {
                    ForEach(recents, id: \.self) { query in
                        Button {
                            onSelect(query)
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "clock.arrow.circlepath")
                                    .foregroundStyle(.secondary)
                                Text(query)
                                    .foregroundStyle(.primary)
                                Spacer()
                                Image(systemName: "arrow.up.left")
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                onRemove(query)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                } header: {
                    HStack {
                        Text("Recent Searches")
                        Spacer()
                        Button("Clear", action: onClear)
                            .font(.caption.weight(.semibold))
                            .textCase(nil)
                    }
                }
            }
            .listStyle(.insetGrouped)
        }
    }
}

#Preview("With Results") {
    let store = NebRatingsStore()
    store.shows = Show.previewData
    
    return NavigationStack {
        SearchShowsView()
            .environment(store)
    }
}

#Preview("Empty State") {
    let store = NebRatingsStore()
    
    return NavigationStack {
        SearchShowsView()
            .environment(store)
    }
}

#Preview("Loading") {
    let store = NebRatingsStore()
    store.isSearchingShows = true
    
    return NavigationStack {
        SearchShowsView()
            .environment(store)
    }
}

