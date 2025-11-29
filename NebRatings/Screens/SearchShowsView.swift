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

    private var filteredShows: [Show] {
        guard !searchText.isEmpty else { return store.shows }
        return store.shows.filter { $0.matches(searchText) }
    }

    var body: some View {
        NavigationStack {
            List(filteredShows) { show in
                NavigationLink(value: show) {
                    ShowRow(show: show)
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Discover")
            .searchable(text: $searchText, prompt: "Search movies or TV shows")
            .navigationDestination(for: Show.self) { show in
                ShowDetailView(show: show)
            }
        }
    }
}

