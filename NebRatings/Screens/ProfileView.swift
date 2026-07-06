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
    @State private var isEditingName = false
    @State private var editedName = ""
    @State private var isUpdatingName = false
    @State private var nameError: String?
    @State private var currentReviewPage: Int = 0
    @State private var navigationPath = NavigationPath()
    @State private var isShowingAvatarPicker = false

    var body: some View {
        NavigationStack(path: $navigationPath) {
            List {
                profileSection
                statsSection
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
            .navigationDestination(for: ShowWithContext.self) { ctx in
                ShowDetailView(show: ctx.show, initialSeasonFilter: ctx.initialSeasonFilter)
            }
            .refreshable {
                await store.loadUserProfile()
            }
            .sheet(isPresented: $isShowingAvatarPicker) {
                AvatarPickerView()
                    .environment(store)
            }
        }
    }

    private var statsSection: some View {
        Section {
            // Reads the persisted aggregate maintained on each review write — no recompute here.
            CriticGaugeView(
                delta: store.currentUser?.criticDelta,
                sampleSize: store.currentUser?.criticSampleSize ?? 0,
                isLoading: store.currentUser == nil
            )
            .listRowInsets(EdgeInsets(top: 8, leading: 8, bottom: 8, trailing: 8))
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)

            TopGenreView(
                genre: store.currentUser?.topGenre,
                isLoading: store.currentUser == nil
            )
            .listRowInsets(EdgeInsets(top: 0, leading: 8, bottom: 8, trailing: 8))
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)

            TopThreePicks(reviews: store.userReviews) { show in
                navigationPath.append(show)
            }
            .environment(store)
            .listRowInsets(EdgeInsets(top: 0, leading: 8, bottom: 8, trailing: 8))
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
        }
    }

    private var profileSection: some View {
        Section("Account") {
            if let user = store.currentUser {
                HStack(spacing: 14) {
                    Button {
                        isShowingAvatarPicker = true
                    } label: {
                        ZStack(alignment: .bottomTrailing) {
                            AvatarView(emoji: user.avatarEmoji, size: 64)
                            Image(systemName: "pencil.circle.fill")
                                .font(.system(size: 22))
                                .foregroundStyle(.white, .purple)
                                .background(Circle().fill(.background))
                                .offset(x: 2, y: 2)
                        }
                    }
                    .buttonStyle(.plain)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Tap avatar to change")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("Tap pencil to edit username")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
                .padding(.vertical, 4)
                .listRowSeparator(.hidden)

                if isEditingName {
                    // Edit mode
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            TextField("Username", text: $editedName)
                                .font(.system(size: 22, weight: .bold, design: .default))
                                .textFieldStyle(.plain)
                                .disabled(isUpdatingName)
                            
                            if isUpdatingName {
                                ProgressView()
                                    .scaleEffect(0.8)
                            } else {
                                Button("Save") {
                                    Task {
                                        await saveName()
                                    }
                                }
                                .buttonStyle(.borderedProminent)
                                .controlSize(.small)
                                .disabled(editedName.trimmingCharacters(in: .whitespaces).isEmpty || editedName.trimmingCharacters(in: .whitespaces) == store.currentUser?.username)
                                
                                Button("Cancel") {
                                    cancelEdit()
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                            }
                        }
                        
                        if let error = nameError {
                            Text(error)
                                .font(.caption)
                                .foregroundStyle(.red)
                        }
                    }
                    .padding(.vertical, 4)
                } else {
                    // Display mode
                    HStack {
                    Text(user.username)
                        .font(.system(size: 22, weight: .bold, design: .default))
                        Spacer()
                        Button {
                            startEditing()
                        } label: {
                            Image(systemName: "pencil")
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.vertical, 4)
                }
            } else {
                ContentUnavailableView("No profile yet", systemImage: "person.crop.circle.badge.questionmark", description: Text("Sign in to load your neb persona."))
            }
        }
    }
    
    private func startEditing() {
        if let user = store.currentUser {
            editedName = user.username
            isEditingName = true
        }
    }
    
    private func cancelEdit() {
        isEditingName = false
        editedName = ""
        nameError = nil
    }
    
    private func saveName() async {
        let trimmedName = editedName.trimmingCharacters(in: .whitespaces)
        guard !trimmedName.isEmpty else {
            return
        }
        
        // Check if name hasn't changed
        if trimmedName == store.currentUser?.username {
            isEditingName = false
            editedName = ""
            nameError = nil
            return
        }
        
        isUpdatingName = true
        nameError = nil
        
        do {
            try await store.updateProfileName(trimmedName)
            isEditingName = false
            editedName = ""
            nameError = nil
        } catch {
            nameError = formatProfileErrorMessage(error)
        }
        
        isUpdatingName = false
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
                let allReviews = sortedReviews
                let pageCount = ReviewPagination.pageCount(for: allReviews.count, pageSize: 5)

                // Sort picker
                ReviewSortPicker(selection: $sortOption)
                    .listRowSeparator(.hidden)
                    .padding(.vertical, 4)
                    .onChange(of: sortOption) { _, _ in
                        currentReviewPage = 0
                    }

                // Pager chevrons (only when there's more than one page)
                if pageCount > 1 {
                    HStack {
                        Spacer()
                        ReviewPagerChevrons(pageCount: pageCount, currentPage: $currentReviewPage)
                    }
                    .listRowSeparator(.hidden)
                }

                // Carousel
                PaginatedReviewsCarousel(
                    reviews: allReviews,
                    pageSize: 5,
                    currentPage: $currentReviewPage,
                    partialPageMessage: "Keep reviewing to see more!"
                ) { review in
                    if let show = store.show(for: review) {
                        Button {
                            navigationPath.append(ShowWithContext(show: show, initialSeasonFilter: review.season))
                        } label: {
                            ReviewCard(review: review,
                                       showTitle: show.title,
                                       showCategory: show.category,
                                       isOwnReview: true,
                                       authorAvatarEmoji: store.currentUser?.avatarEmoji,
                                       currentUserID: store.currentUser?.id,
                                       onReact: { emoji in
                                           Task { await store.setReaction(emoji: emoji, on: review) }
                                       })
                        }
                        .buttonStyle(.plain)
                    }
                }
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets())
            }
        } header: {
            HStack(spacing: 8) {
                Text("Your Reviews")
                if !store.userReviews.isEmpty {
                    ReviewCountBadge(count: store.userReviews.count)
                        .textCase(nil) // Section headers force uppercase; the badge is its own thing.
                }
                Spacer()
            }
        }
        .sheet(item: $reviewToEdit) { review in
            EditReviewView(review: review)
                .environment(store)
        }
    }
    
    private func formatProfileErrorMessage(_ error: Error) -> String {
        let errorString = error.localizedDescription.lowercased()
        
        // Username already taken
        if errorString.contains("username") && (errorString.contains("already taken") || errorString.contains("already exists") || errorString.contains("taken")) {
            return "This username is already taken. Please choose a different one."
        }
        
        // Empty name
        if errorString.contains("name") && (errorString.contains("empty") || errorString.contains("cannot be empty") || errorString.contains("required")) {
            return "Username cannot be empty"
        }
        
        // Invalid name format
        if errorString.contains("invalid") && errorString.contains("name") {
            return "Username contains invalid characters. Please use only letters, numbers, and spaces."
        }
        
        // Network errors
        if errorString.contains("network") || 
           errorString.contains("connection") || 
           errorString.contains("internet") ||
           errorString.contains("offline") ||
           errorString.contains("timeout") {
            return "Connection problem. Please check your internet and try again"
        }
        
        // Permission errors
        if errorString.contains("permission") || errorString.contains("unauthorized") {
            return "You don't have permission to update your profile. Please try again"
        }
        
        // Default fallback
        return "Unable to update username. Please try again"
    }
    
}

