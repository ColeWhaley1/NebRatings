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
            VStack(spacing: 0) {
                // Category filter picker
                categoryFilterView
                
                // Results list
                Group {
                    if store.isSearchingShows {
                        ProgressView("Searching...")
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else if store.shows.isEmpty && !searchText.isEmpty {
                        ContentUnavailableView("No results", systemImage: "magnifyingglass", description: Text("Try a different search term."))
                    } else if store.shows.isEmpty {
                        ContentUnavailableView("Search for shows", systemImage: "magnifyingglass", description: Text("Enter a movie or TV show name to search."))
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
            .navigationTitle("Discover")
            .searchable(text: $searchText, prompt: "Search movies or TV shows")
            .onChange(of: searchText) { oldValue, newValue in
                if newValue.isEmpty {
                    loadTrending()
                } else {
                    performSearch()
                }
            }
            .onChange(of: selectedCategory) { oldValue, newValue in
                if searchText.isEmpty {
                    loadTrending()
                } else {
                    performSearch()
                }
            }
            .onAppear {
                if searchText.isEmpty {
                    loadTrending()
                }
            }
            .navigationDestination(for: Show.self) { show in
                ShowDetailView(show: show)
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
    
    private func loadTrending() {
        // Cancel any pending search task
        searchTask?.cancel()
        
        Task {
            await store.loadTrendingShows(category: selectedCategory)
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

