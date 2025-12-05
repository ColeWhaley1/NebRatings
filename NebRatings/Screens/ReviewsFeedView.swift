//
//  ReviewsFeedView.swift
//  NebRatings
//
//  Created by Cole Whaley on 11/29/25.
//

import SwiftUI

struct ReviewsFeedView: View {
    enum CategoryFilter: String, CaseIterable, Identifiable {
        case all = "All"
        case movies = "Movies"
        case series = "Series"

        var id: String { rawValue }

        var category: Show.Category? {
            switch self {
            case .all: return nil
            case .movies: return .movie
            case .series: return .series
            }
        }
    }

    @Environment(NebRatingsStore.self) private var store: NebRatingsStore
    @State private var searchText = ""
    @State private var categoryFilter: CategoryFilter = .all
    @State private var minimumRating: Double = 0
    @State private var queryTask: Task<Void, Never>?

    var body: some View {
        NavigationStack {
            List {
                filterSection
                reviewsSection
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Community Nebs")
            .navigationDestination(for: Show.self) { show in
                ShowDetailView(show: show)
            }
            .searchable(text: $searchText, prompt: "Search reviews")
            .onAppear {
                performQuery()
            }
            .onChange(of: searchText) { _, _ in
                performQuery()
            }
            .onChange(of: categoryFilter) { _, _ in
                performQuery()
            }
            .onChange(of: minimumRating) { _, _ in
                performQuery()
            }
        }
    }
    
    private func performQuery() {
        // Cancel previous query task
        queryTask?.cancel()
        
        // Debounce query - wait 0.3 seconds after filter changes
        queryTask = Task {
            try? await Task.sleep(nanoseconds: 300_000_000) // 0.3 seconds
            
            guard !Task.isCancelled else { return }
            
            let searchQuery = searchText.isEmpty ? nil : searchText
            await store.queryReviews(
                searchText: searchQuery,
                category: categoryFilter.category,
                minimumRating: minimumRating > 0 ? minimumRating : nil
            )
        }
    }

    private var filterSection: some View {
        Section("Filters") {
            Picker("Category", selection: $categoryFilter) {
                ForEach(CategoryFilter.allCases) { filter in
                    Text(filter.rawValue).tag(filter)
                }
            }
            .pickerStyle(.segmented)

            VStack(alignment: .leading) {
                Text("Minimum rating: \(minimumRating, specifier: "%.1f") nebs")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Slider(value: $minimumRating, in: 0...5, step: 0.5)
                    .tint(.purple)
            }
        }
    }

    private var reviewsSection: some View {
        Section("Reviews") {
            if store.isQueryingReviews {
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
                .padding()
            } else if store.reviews.isEmpty {
                ContentUnavailableView("No reviews match", systemImage: "text.magnifyingglass", description: Text("Try adjusting the filters."))
            } else {
                ForEach(store.reviews) { review in
                    let show = store.show(for: review)
                    NavigationLink(value: show) {
                        ReviewCard(review: review,
                                   showTitle: show?.title ?? review.showTitle,
                                   showCategory: show?.category ?? review.showCategory)
                    }
                    .buttonStyle(.plain)
                }
                .listRowSeparator(.hidden)
            }
        }
    }
}
