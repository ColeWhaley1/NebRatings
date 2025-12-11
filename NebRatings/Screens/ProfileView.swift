//
//  ProfileView.swift
//  NebRatings
//
//  Created by Cole Whaley on 11/29/25.
//

import SwiftUI

struct ProfileView: View {
    enum ReviewSortOption: String, CaseIterable, Identifiable {
        case mostRecent = "Most Recent"
        case leastRecent = "Least Recent"
        case highestRating = "Highest Rating"
        case lowestRating = "Lowest Rating"
        
        var id: String { rawValue }
    }
    
    @Environment(NebRatingsStore.self) private var store: NebRatingsStore
    @State private var reviewToEdit: Review?
    @State private var sortOption: ReviewSortOption = .mostRecent

    var body: some View {
        NavigationStack {
            List {
                profileSection
                reviewsSection
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    NavigationLink {
                        SettingsView()
                            .environment(store)
                    } label: {
                        Image(systemName: "gearshape.fill")
                            .foregroundStyle(.primary)
                    }
                }
            }
            .navigationDestination(for: Show.self) { show in
                ShowDetailView(show: show)
            }
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

    private var sortedReviews: [Review] {
        switch sortOption {
        case .mostRecent:
            return store.userReviews.sorted { $0.timestamp > $1.timestamp }
        case .leastRecent:
            return store.userReviews.sorted { $0.timestamp < $1.timestamp }
        case .highestRating:
            return store.userReviews.sorted { $0.nebRating > $1.nebRating }
        case .lowestRating:
            return store.userReviews.sorted { $0.nebRating < $1.nebRating }
        }
    }
    
    private var reviewsSection: some View {
        Section {
            if store.userReviews.isEmpty {
                ContentUnavailableView("No reviews posted", systemImage: "text.bubble", description: Text("Start dropping nebs from the Discover tab."))
            } else {
                // Sort filter picker with styled header
                HStack {
                    Label("Sort", systemImage: "arrow.up.arrow.down")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Picker("", selection: $sortOption) {
                        ForEach(ReviewSortOption.allCases) { option in
                            Text(option.rawValue).tag(option)
                        }
                    }
                    .pickerStyle(.menu)
                }
                .padding(.vertical, 4)
                
                ForEach(sortedReviews) { review in
                    let show = store.show(for: review)
                    if let show = show {
                        NavigationLink(value: show) {
                            ReviewCard(review: review,
                                       showTitle: show.title,
                                       showCategory: show.category,
                                       isOwnReview: true)
                        }
                        .buttonStyle(.plain)
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button {
                                store.deleteReview(review)
                            } label: {
                                Label("Delete", systemImage: "trash")
                                    .symbolRenderingMode(.hierarchical)
                            }
                            .tint(Color.red.opacity(0.7))
                            
                            Button {
                                reviewToEdit = review
                            } label: {
                                Label("Edit", systemImage: "pencil.line")
                            }
                            .tint(Color.blue.opacity(0.7))
                        }
                    }
                }
                .listRowSeparator(.hidden)
            }
        } header: {
            Text("Your Reviews")
        }
        .sheet(item: $reviewToEdit) { review in
            EditReviewView(review: review)
                .environment(store)
        }
    }
    
}

