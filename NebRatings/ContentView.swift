//
//  ContentView.swift
//  NebRatings
//
//  Created by Cole Whaley on 11/28/25.
//

import SwiftUI

/// Root tabs. Selection lives in `NebRatingsStore.selectedTab` so any view
/// can programmatically switch tabs (e.g. "view my own profile" routes here).
enum AppTab: Hashable {
    case discover
    case activity
    case lists
    case friends
    case profile
}

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
        @Bindable var store = store
        return Group {
            if store.isAuthenticated {
                TabView(selection: $store.selectedTab) {
                    SearchShowsView()
                        .tabItem {
                            Label("Discover", systemImage: "magnifyingglass")
                        }
                        .tag(AppTab.discover)

                    ActivityTabView()
                        .tabItem {
                            Label("Activity", systemImage: "sparkles")
                        }
                        .tag(AppTab.activity)

                    ListsView()
                        .tabItem {
                            Label("Lists", systemImage: "list.bullet.rectangle")
                        }
                        .tag(AppTab.lists)

                    FriendsView()
                        .tabItem {
                            Label("Friends", systemImage: "person.2.fill")
                        }
                        .tag(AppTab.friends)

                    ProfileView()
                        .tabItem {
                            Label("Profile", systemImage: "person.crop.circle")
                        }
                        .tag(AppTab.profile)
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
