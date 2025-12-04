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
    var isOwnReview: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let showTitle {
                HStack(spacing: 8) {
                    if let showCategory {
                        Text(showCategory.rawValue.uppercased())
                            .font(.caption.bold())
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(showCategory.badgeColor.opacity(0.15), in: Capsule())
                            .foregroundStyle(showCategory.badgeColor)
                    }
                    Text(showTitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            HStack {
                HStack(spacing: 6) {
                    Text(review.author)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    if isOwnReview {
                        Text("(You)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.purple.opacity(0.15), in: Capsule())
                            .foregroundStyle(.purple)
                    }
                }
                Spacer()
                NebRatingView(rating: review.nebRating)
            }
            Text(review.comment)
                .font(.body)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
            Text(review.timestamp.formatted(date: .abbreviated, time: .shortened))
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

