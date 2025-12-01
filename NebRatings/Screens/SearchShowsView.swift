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
    @State private var searchTask: Task<Void, Never>?

    var body: some View {
        NavigationStack {
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
            .navigationTitle("Discover")
            .searchable(text: $searchText, prompt: "Search movies or TV shows")
            .onChange(of: searchText) { oldValue, newValue in
                // Cancel previous search task
                searchTask?.cancel()
                
                // Debounce search - wait 0.5 seconds after user stops typing
                searchTask = Task {
                    try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
                    
                    guard !Task.isCancelled else { return }
                    await store.searchShows(query: newValue)
                }
            }
            .navigationDestination(for: Show.self) { show in
                ShowDetailView(show: show)
            }
        }
    }
}

