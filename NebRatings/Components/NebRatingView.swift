//
//  NebRatingView.swift
//  NebRatings
//
//  Created by Cole Whaley on 11/29/25.
//

import SwiftUI

struct NebRatingView: View {
    let rating: Double
    var isOwnReview: Bool = false
    private let maxNebs = 5
    @Environment(\.colorScheme) var colorScheme
    
    private var ratingEmoji: String? {
        // Ratings are now on 0-10 scale
        if rating >= 8.0 {
            return "🔥" // 8.0 or better - Fire
        } else if rating <= 4.0 {
            return "🤮" // 4.0 or worse - Throw up
        }
        return nil // No emoji for values in between
    }
    
    private var displayedRating: Double {
        // Ratings are stored and displayed on 0-10 scale directly
        return rating
    }

    var body: some View {
        HStack(spacing: 6) {
            if let emoji = ratingEmoji {
                Text(emoji)
                    .font(.title3)
            }
            HStack(spacing: 4) {
                Text(String(format: "%.1f", displayedRating))
                    .font(.title2.bold()) // Larger and bolder for emphasis
                    .foregroundStyle(.primary) // Primary color instead of secondary for visibility
                Text("/ 10")
                    .font(.title3) // Slightly smaller than the number
                    .foregroundStyle(.secondary) // Less prominent
            }
        }
        .lineLimit(1)
        .fixedSize(horizontal: true, vertical: false)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(
                    isOwnReview 
                        ? Color.purple.opacity(0.2)
                        : (colorScheme == .dark ? Color.white.opacity(0.2) : Color.black.opacity(0.1))
                )
                .shadow(color: .black.opacity(0.15), radius: 3, x: 0, y: 2)
        )
        .accessibilityLabel("\(displayedRating, specifier: "%.1f") out of 10 nebs")
    }
}



