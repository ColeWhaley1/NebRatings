//
//  ReviewCard.swift
//  NebRatings
//
//  Created by Cole Whaley on 11/29/25.
//

import SwiftUI

struct ReviewCard: View {
    let review: Review
    var showTitle: String?
    var showCategory: Show.Category?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let showTitle {
                HStack(spacing: 8) {
                    if let showCategory {
                        Text(showCategory.rawValue.uppercased())
                            .font(.caption2.bold())
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(showCategory.badgeColor.opacity(0.15), in: Capsule())
                            .foregroundStyle(showCategory.badgeColor)
                    }
                    Text(showTitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            HStack {
                Text(review.author)
                    .font(.headline)
                Spacer()
                NebRatingView(rating: review.nebRating)
            }
            Text(review.comment)
                .font(.body)
            Text(review.timestamp.formatted(date: .abbreviated, time: .shortened))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }
}

