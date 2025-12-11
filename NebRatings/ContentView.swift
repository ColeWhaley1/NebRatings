//
//  ContentView.swift
//  NebRatings
//
//  Created by Cole Whaley on 11/28/25.
//

import SwiftUI

struct ContentView: View {
    @Environment(NebRatingsStore.self) private var store: NebRatingsStore
    @AppStorage("colorScheme") private var colorScheme: String = "dark"
    
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
        Group {
            if store.isAuthenticated {
                TabView {
                    SearchShowsView()
                        .tabItem {
                            Label("Discover", systemImage: "magnifyingglass")
                        }

                    ReviewsFeedView()
                        .tabItem {
                            Label("Reviews", systemImage: "text.bubble")
                        }
                    
                    ListsView()
                        .tabItem {
                            Label("Lists", systemImage: "list.bullet.rectangle")
                        }

                    ProfileView()
                        .tabItem {
                            Label("Profile", systemImage: "person.crop.circle")
                        }
                }
            } else {
                SignInView()
            }
        }
        .preferredColorScheme(selectedColorScheme)
    }
}
#Preview {
    ContentView()
        .environment(NebRatingsStore())
}
