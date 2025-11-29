//
//  ContentView.swift
//  NebRatings
//
//  Created by Cole Whaley on 11/28/25.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            SearchShowsView()
                .tabItem {
                    Label("Discover", systemImage: "magnifyingglass")
                }

            ReviewsFeedView()
                .tabItem {
                    Label("Reviews", systemImage: "text.bubble")
                }

            ProfileView()
                .tabItem {
                    Label("Profile", systemImage: "person.crop.circle")
                }
        }
    }
}

#Preview {
    ContentView()
        .environment(NebRatingsStore())
}
