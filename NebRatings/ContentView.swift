//
//  ContentView.swift
//  NebRatings
//
//  Created by Cole Whaley on 11/28/25.
//

import SwiftUI

struct ContentView: View {
    @AppStorage("colorScheme") private var colorScheme: String = "system"
    
    private var selectedColorScheme: ColorScheme? {
        switch colorScheme {
        case "light":
            return .light
        case "dark":
            return .dark
        default:
            return nil // system
        }
    }
    
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
        .preferredColorScheme(selectedColorScheme)
    }
}

#Preview {
    ContentView()
        .environment(NebRatingsStore())
}
