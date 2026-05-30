//
//  ShowDetailHelpers.swift
//  NebRatings
//
//  Shared helpers and utilities for ShowDetailView and its subviews.
//

import SwiftUI

// MARK: - PreferenceKey

struct ReviewHeightPreferenceKey: PreferenceKey {
    static var defaultValue: [UUID: CGFloat] = [:]
    
    static func reduce(value: inout [UUID: CGFloat], nextValue: () -> [UUID: CGFloat]) {
        value.merge(nextValue()) { _, new in new }
    }
}

// MARK: - Review Helpers

enum ShowDetailHelpers {
    // Pagination helpers moved to `ReviewPagination` in PaginatedReviewsCarousel.swift.

    static func ratingEmoji(for rating: Double) -> String? {
        if rating >= 8.0 {
            return "🔥"
        } else if rating <= 4.0 {
            return "🤮"
        }
        return nil
    }
    
    static func displayedRating(for rating: Double) -> Double {
        return rating
    }
    
    static func seasonLabelForPicker(_ seasons: [Int]?) -> String {
        guard let seasons = seasons, !seasons.isEmpty else {
            return "Entire show"
        }
        let sorted = seasons.sorted()
        if sorted.count == 1 {
            return "Season \(sorted[0])"
        }
        return "Seasons \(sorted.map { String($0) }.joined(separator: ", "))"
    }
}
