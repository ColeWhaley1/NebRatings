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

    private var filteredReviews: [Review] {
        store.reviews.filter { review in
            matchesSearch(review: review)
            && matchesCategory(review: review)
            && review.nebRating >= minimumRating
        }
    }

    private func matchesSearch(review: Review) -> Bool {
        guard !searchText.isEmpty else { return true }
        let lowered = searchText.lowercased()
        return review.comment.lowercased().contains(lowered)
        || review.author.lowercased().contains(lowered)
        || review.showTitle.lowercased().contains(lowered)
    }

    private func matchesCategory(review: Review) -> Bool {
        guard let selectedCategory = categoryFilter.category else { return true }
        return store.show(for: review)?.category == selectedCategory
    }

    var body: some View {
        NavigationStack {
            List {
                filterSection
                reviewsSection
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Community Nebs")
            .searchable(text: $searchText, prompt: "Search reviews")
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
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Slider(value: $minimumRating, in: 0...5, step: 0.5)
                    .tint(.purple)
            }
        }
    }

    private var reviewsSection: some View {
        Section("Reviews") {
            if filteredReviews.isEmpty {
                ContentUnavailableView("No reviews match", systemImage: "text.magnifyingglass", description: Text("Try adjusting the filters."))
            } else {
                ForEach(filteredReviews) { review in
                    let show = store.show(for: review)
                    ReviewCard(review: review,
                               showTitle: show?.title ?? review.showTitle,
                               showCategory: show?.category)
                }
                .listRowSeparator(.hidden)
            }
        }
    }
}
