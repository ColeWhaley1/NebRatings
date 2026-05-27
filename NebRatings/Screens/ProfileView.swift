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
    @State private var criticDelta: Double?
    @State private var criticSampleSize: Int = 0
    @State private var isLoadingGauge = true
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
            .task(id: store.userReviews.count) {
                await refreshCriticGauge()
            }
            .refreshable {
                await store.loadUserProfile()
                await refreshCriticGauge()
            }
            .sheet(isPresented: $isShowingAvatarPicker) {
                AvatarPickerView()
                    .environment(store)
            }
        }
    }

    private var statsSection: some View {
        Section {
            CriticGaugeView(delta: criticDelta, sampleSize: criticSampleSize, isLoading: isLoadingGauge)
                .listRowInsets(EdgeInsets(top: 8, leading: 8, bottom: 8, trailing: 8))
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

    private func refreshCriticGauge() async {
        isLoadingGauge = true
        if let result = await store.computeCriticDelta(reviews: store.userReviews) {
            criticDelta = result.delta
            criticSampleSize = result.sampleSize
        } else {
            criticDelta = nil
            criticSampleSize = 0
        }
        isLoadingGauge = false
    }

    private var profileSection: some View {
        Section("Account") {
            if let user = store.currentUser {
                HStack(spacing: 14) {
                    Button {
                        isShowingAvatarPicker = true
                    } label: {
                        ZStack(alignment: .bottomTrailing) {
                            AvatarView(emoji: user.avatarEmoji, photoURL: user.avatarPhotoURL, size: 64)
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
                let reviewPages = chunkReviews(allReviews, pageSize: 5)
                
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
                .listRowSeparator(.hidden)
                .padding(.vertical, 4)
                .onChange(of: sortOption) { _, _ in
                    // Reset to first page when sort changes
                    currentReviewPage = 0
                }
                
                // Navigation arrows for carousel
                if !allReviews.isEmpty && reviewPages.count > 1 {
                    HStack {
                        Spacer()
                        
                        // Previous page arrow - separate button
                        Button {
                            if currentReviewPage > 0 {
                                currentReviewPage -= 1
                            }
                        } label: {
                            Image(systemName: "chevron.left")
                                .font(.title3)
                                .foregroundStyle(currentReviewPage > 0 ? Color.primary : Color.gray.opacity(0.3))
                                .frame(width: 32, height: 32)
                        }
                        .disabled(currentReviewPage == 0)
                        .buttonStyle(.plain)
                        
                        // Spacing between buttons
                        Spacer()
                            .frame(width: 8)
                        
                        // Next page arrow - separate button
                        Button {
                            if currentReviewPage < reviewPages.count - 1 {
                                currentReviewPage += 1
                            }
                        } label: {
                            Image(systemName: "chevron.right")
                                .font(.title3)
                                .foregroundStyle(currentReviewPage < reviewPages.count - 1 ? Color.primary : Color.gray.opacity(0.3))
                                .frame(width: 32, height: 32)
                        }
                        .disabled(currentReviewPage >= reviewPages.count - 1)
                        .buttonStyle(.plain)
                    }
                    .listRowSeparator(.hidden)
                }
                
                // Carousel for reviews
                if allReviews.isEmpty {
                    ContentUnavailableView("No reviews", systemImage: "text.bubble")
                } else {
                    VStack(spacing: 12) {
                        // TabView for smooth page transitions
                        TabView(selection: $currentReviewPage) {
                            ForEach(0..<reviewPages.count, id: \.self) { pageIndex in
                                HStack(spacing: 0) {
                                    // Left spacing for gap between pages
                                    Spacer()
                                        .frame(width: 8)
                                    
                                    // Content area with full-width cards using ScrollView + LazyVStack
                                    ScrollView {
                                        LazyVStack(spacing: 8) {
                                            ForEach(reviewPages[pageIndex]) { review in
                                                let show = store.show(for: review)
                                                if let show = show {
                                                    Button {
                                                        navigationPath.append(ShowWithContext(show: show, initialSeasonFilter: review.season))
                                                    } label: {
                                                        ReviewCard(review: review,
                                                                   showTitle: show.title,
                                                                   showCategory: show.category,
                                                                   isOwnReview: true)
                                                    }
                                                    .buttonStyle(.plain)
                                                }
                                            }
                                            
                                            // Subtle message if less than 5 reviews on this page
                                            if reviewPages[pageIndex].count < 5 {
                                                Spacer()
                                                    .frame(height: 20)
                                                
                                                Text("Keep reviewing to see more!")
                                                    .font(.caption)
                                                    .foregroundStyle(.secondary)
                                                    .padding(.top, 8)
                                                
                                                Spacer()
                                            }
                                        }
                                        .padding(.top, 8)
                                        .padding(.bottom, 8)
                                    }
                                    .scrollDisabled(true)
                                    .frame(maxWidth: .infinity, alignment: .topLeading)
                                    
                                    // Right spacing for gap between pages
                                    Spacer()
                                        .frame(width: 8)
                                }
                                .tag(pageIndex)
                            }
                        }
                        .tabViewStyle(.page(indexDisplayMode: .never))
                        .frame(height: calculateActualCarouselHeight(for: allReviews, reviewPages: reviewPages))
                    
                        // Page indicator
                        if reviewPages.count > 1 {
                            if reviewPages.count > 10 {
                                // Use number indicator for more than 50 reviews (10+ pages)
                                Text("\(currentReviewPage + 1) of \(reviewPages.count)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .padding(.top, 4)
                                    .padding(.bottom, 16)
                            } else {
                                // Use dots for 10 or fewer pages
                                HStack(spacing: 6) {
                                    ForEach(0..<reviewPages.count, id: \.self) { index in
                                        Circle()
                                            .fill(index == currentReviewPage ? Color.primary : Color.gray.opacity(0.3))
                                            .frame(width: 8, height: 8)
                                    }
                                }
                                .padding(.top, 4)
                                .padding(.bottom, 16)
                            }
                        }
                }
                .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets())
                }
            }
        } header: {
            Text("Your Reviews")
        }
        .sheet(item: $reviewToEdit) { review in
            EditReviewView(review: review)
                .environment(store)
        }
        .onChange(of: sortedReviews.count) { _, _ in
            // Reset to first page if reviews change
            if currentReviewPage > 0 && sortedReviews.isEmpty {
                currentReviewPage = 0
            }
        }
    }
    
    private func chunkReviews(_ reviews: [Review], pageSize: Int) -> [[Review]] {
        var chunks: [[Review]] = []
        for i in stride(from: 0, to: reviews.count, by: pageSize) {
            let chunk = Array(reviews[i..<min(i + pageSize, reviews.count)])
            chunks.append(chunk)
        }
        return chunks
    }
    
    private func calculateMaxCarouselHeight(for reviewPages: [[Review]]) -> CGFloat {
        // Fixed height: 220pt per review card + 8pt spacing between cards
        // listRowInsets add 8pt top/bottom padding per row (already included in spacing calculation)
        // Max 5 reviews per page
        let cardHeight: CGFloat = 220
        let spacing: CGFloat = 8  // This is the spacing between cards (8pt from listRowInsets bottom + 8pt from next row's top)
        let buffer: CGFloat = 48  // Extra buffer to prevent cutoff (increased from 16)
        let maxReviewsPerPage = 5
        // Calculate: (5 cards * 200) + (4 gaps * 8) + buffer = 1000 + 32 + 48 = 1080
        let totalHeight = CGFloat(maxReviewsPerPage) * cardHeight + CGFloat(maxReviewsPerPage - 1) * spacing + buffer
        return totalHeight
    }
    
    private func calculateActualCarouselHeight(for allReviews: [Review], reviewPages: [[Review]]) -> CGFloat {
        // Fixed height: 220pt per review card + 8pt spacing between cards
        // listRowInsets add 8pt top/bottom padding per row, creating 8pt gaps between cards
        // Add extra buffer to prevent cutoff
        let cardHeight: CGFloat = 220
        let spacing: CGFloat = 8
        let buffer: CGFloat = 48  // Extra buffer to prevent cutoff (increased from 32)
        
        // Calculate height for each page and use the maximum
        var maxPageHeight: CGFloat = 0
        for page in reviewPages {
            let reviewCount = page.count
            let pageHeight = CGFloat(reviewCount) * cardHeight + CGFloat(max(0, reviewCount - 1)) * spacing + buffer
            maxPageHeight = max(maxPageHeight, pageHeight)
        }
        return maxPageHeight
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

