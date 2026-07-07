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
    @State private var selectedCategory: Show.Category? = nil
    @State private var searchTask: Task<Void, Never>?

    var body: some View {
        NavigationStack {
            Group {
                if searchText.isEmpty {
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
                                }
                                .listStyle(.insetGrouped)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Discover")
            .searchable(text: $searchText, prompt: "Search movies or TV shows")
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
            .navigationDestination(for: Show.self) { show in
                ShowDetailView(show: show)
            }
            .navigationDestination(for: Mood.self) { mood in
                MoodResultsView(mood: mood)
            }
        }
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

