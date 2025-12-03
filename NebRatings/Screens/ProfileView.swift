//
//  ProfileView.swift
//  NebRatings
//
//  Created by Cole Whaley on 11/29/25.
//

import SwiftUI

struct ProfileView: View {
    @Environment(NebRatingsStore.self) private var store: NebRatingsStore
    @AppStorage("colorScheme") private var colorScheme: String = "system"

    var body: some View {
        NavigationStack {
            List {
                profileSection
                reviewsSection
                settingsSection
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Profile")
            .refreshable {
                await store.loadUserProfile()
            }
        }
    }

    private var profileSection: some View {
        Section("Account") {
            if let user = store.currentUser {
                VStack(alignment: .leading, spacing: 8) {
                    Text(user.name)
                        .font(.system(size: 22, weight: .bold, design: .default))
                }
                .padding(.vertical, 4)
            } else {
                ContentUnavailableView("No profile yet", systemImage: "person.crop.circle.badge.questionmark", description: Text("Sign in to load your neb persona."))
            }
        }
    }

    private var reviewsSection: some View {
        Section("Your Reviews") {
            if store.userReviews.isEmpty {
                ContentUnavailableView("No reviews posted", systemImage: "text.bubble", description: Text("Start dropping nebs from the Discover tab."))
            } else {
                ForEach(store.userReviews) { review in
                    let show = store.show(for: review)
                    ReviewCard(review: review,
                               showTitle: show?.title ?? review.showTitle,
                               showCategory: show?.category)
                }
                .listRowSeparator(.hidden)
            }
        }
    }
    
    private var settingsSection: some View {
        Section("Settings") {
            Picker("Appearance", selection: $colorScheme) {
                Text("System").tag("system")
                Text("Light").tag("light")
                Text("Dark").tag("dark")
            }
            .pickerStyle(.menu)
            
            Button(role: .destructive, action: {
                Task {
                    await store.signOut()
                }
            }) {
                Label("Sign Out", systemImage: "arrow.right.square")
            }
        }
    }
}

