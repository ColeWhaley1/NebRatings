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
    @State private var currentReviewPage: Int = 0
    @State private var navigationPath = NavigationPath()

    var body: some View {
        NavigationStack(path: $navigationPath) {
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
                if isEditingName {
                    // Edit mode
                    HStack {
                        TextField("Name", text: $editedName)
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
                            
                            Button("Cancel") {
                                cancelEdit()
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                    }
                    .padding(.vertical, 4)
                } else {
                    // Display mode
                    HStack {
                    Text(user.name)
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
            editedName = user.name
            isEditingName = true
        }
    }
    
    private func cancelEdit() {
        isEditingName = false
        editedName = ""
    }
    
    private func saveName() async {
        guard !editedName.trimmingCharacters(in: .whitespaces).isEmpty else {
            return
        }
        
        isUpdatingName = true
        await store.updateProfileName(editedName)
        isUpdatingName = false
        isEditingName = false
        editedName = ""
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
                                                        navigationPath.append(show)
                                                    } label: {
                                                        ReviewCard(review: review,
                                                                   showTitle: show.title,
                                                                   showCategory: show.category,
                                                                   isOwnReview: true)
                                                    }
                                                    .buttonStyle(.plain)
                                                }
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
        // Fixed height: 200pt per review card + 8pt spacing between cards
        // listRowInsets add 8pt top/bottom padding per row (already included in spacing calculation)
        // Max 5 reviews per page
        let cardHeight: CGFloat = 200
        let spacing: CGFloat = 8  // This is the spacing between cards (8pt from listRowInsets bottom + 8pt from next row's top)
        let buffer: CGFloat = 48  // Extra buffer to prevent cutoff (increased from 16)
        let maxReviewsPerPage = 5
        // Calculate: (5 cards * 200) + (4 gaps * 8) + buffer = 1000 + 32 + 48 = 1080
        let totalHeight = CGFloat(maxReviewsPerPage) * cardHeight + CGFloat(maxReviewsPerPage - 1) * spacing + buffer
        return totalHeight
    }
    
    private func calculateActualCarouselHeight(for allReviews: [Review], reviewPages: [[Review]]) -> CGFloat {
        // Fixed height: 200pt per review card + 8pt spacing between cards
        // listRowInsets add 8pt top/bottom padding per row, creating 8pt gaps between cards
        // Add extra buffer to prevent cutoff
        let cardHeight: CGFloat = 200
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
    
}

