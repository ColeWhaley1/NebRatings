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
    /// One-time content-preference prompt (onboarding). Shown once per
    /// launch at most, only while the profile has never chosen.
    @State private var showingContentPreferencePrompt = false
    @State private var hasOfferedContentPreferencePrompt = false

    // MARK: Deep linking
    /// Parsed-but-not-yet-shown link. Held until the user is authenticated
    /// (a link can arrive at a cold launch, before sign-in resolves).
    @State private var pendingLink: DeepLink?
    /// Resolved presentation targets — shown as sheets from the root, which
    /// works regardless of the active tab and needs no per-tab plumbing.
    @State private var linkedShow: Show?
    @State private var linkedProfile: ProfileLinkTarget?
    
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
        .onChange(of: store.needsContentPreferencePrompt) { _, needsPrompt in
            if needsPrompt && !hasOfferedContentPreferencePrompt {
                hasOfferedContentPreferencePrompt = true
                showingContentPreferencePrompt = true
            }
        }
        .sheet(isPresented: $showingContentPreferencePrompt) {
            ContentPreferenceOnboardingSheet()
                .environment(store)
        }
        // Deep links (custom scheme now, Universal Links once configured).
        .onOpenURL { url in
            guard let link = DeepLinkParser.parse(url) else { return }
            pendingLink = link
            resolvePendingLink()
        }
        .onChange(of: store.isAuthenticated) { _, isAuthed in
            // A link that arrived before sign-in resolves once we're in.
            if isAuthed { resolvePendingLink() }
        }
        .sheet(item: $linkedShow) { show in
            NavigationStack {
                ShowDetailView(show: show)
                    .toolbar {
                        ToolbarItem(placement: .topBarLeading) {
                            Button("Done") { linkedShow = nil }
                        }
                    }
                    .modifier(DeepLinkDestinations())
            }
            .environment(store)
        }
        .sheet(item: $linkedProfile) { target in
            NavigationStack {
                UserProfileView(userID: target.userID)
                    .toolbar {
                        ToolbarItem(placement: .topBarLeading) {
                            Button("Done") { linkedProfile = nil }
                        }
                    }
                    .modifier(DeepLinkDestinations())
            }
            .environment(store)
        }
    }

    /// Presents the pending link once we're authenticated. Shows resolve
    /// through TMDB (id + category → full Show); profiles present directly.
    private func resolvePendingLink() {
        guard store.isAuthenticated, let link = pendingLink else { return }
        pendingLink = nil
        switch link {
        case .show(let id, let category):
            Task {
                if let show = await store.fetchShowDetailsByTMDBID(tmdbID: id, category: category) {
                    linkedShow = show
                }
            }
        case .profile(let userID):
            linkedProfile = ProfileLinkTarget(userID: userID)
        }
    }
}

/// Registers the standard push destinations so a deep-linked detail screen
/// (presented in its own sheet stack) navigates exactly like it does inside
/// a tab — recommendations, review→show, and profile pushes all work.
private struct DeepLinkDestinations: ViewModifier {
    func body(content: Content) -> some View {
        content
            .navigationDestination(for: Show.self) { show in
                ShowDetailView(show: show)
            }
            .navigationDestination(for: ShowWithContext.self) { ctx in
                ShowDetailView(show: ctx.show, initialSeasonFilter: ctx.initialSeasonFilter)
            }
            .navigationDestination(for: UserProfileDestination.self) { dest in
                UserProfileView(userID: dest.userID, initialProfile: dest.profile)
            }
    }
}
#Preview {
    ContentView()
        .environment(NebRatingsStore())
}
