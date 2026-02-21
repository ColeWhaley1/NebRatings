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
    static func chunkReviews(_ reviews: [Review], pageSize: Int) -> [[Review]] {
        var chunks: [[Review]] = []
        for i in stride(from: 0, to: reviews.count, by: pageSize) {
            let chunk = Array(reviews[i..<min(i + pageSize, reviews.count)])
            chunks.append(chunk)
        }
        return chunks
    }
    
    static func calculateActualCarouselHeight(for reviews: [Review], reviewPages: [[Review]]) -> CGFloat {
        let cardHeight: CGFloat = 220
        let spacing: CGFloat = 8
        let buffer: CGFloat = 48
        
        var maxPageHeight: CGFloat = 0
        for page in reviewPages {
            let reviewCount = page.count
            let pageHeight = CGFloat(reviewCount) * cardHeight + CGFloat(max(0, reviewCount - 1)) * spacing + buffer
            maxPageHeight = max(maxPageHeight, pageHeight)
        }
        return maxPageHeight
    }
    
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
