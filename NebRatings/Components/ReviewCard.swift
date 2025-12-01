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
                            .font(.caption.bold())
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(
                                LinearGradient(
                                    colors: [showCategory.badgeColor.opacity(0.25), showCategory.badgeColor.opacity(0.15)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                ),
                                in: Capsule()
                            )
                            .foregroundStyle(showCategory.badgeColor)
                            .shadow(color: showCategory.badgeColor.opacity(0.3), radius: 4, x: 0, y: 2)
                    }
                    Text(showTitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            HStack {
                Text(review.author)
                    .font(.system(size: 17, weight: .semibold, design: .default))
                    .foregroundStyle(.primary)
                Spacer()
                NebRatingView(rating: review.nebRating)
            }
            Text(review.comment)
                .font(.system(size: 16, weight: .regular, design: .default))
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
            Text(review.timestamp.formatted(date: .abbreviated, time: .shortened))
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color(.separator), lineWidth: 1.5)
        )
        .frame(maxWidth: .infinity, alignment: .leading)
        .transition(.scale.combined(with: .opacity))
    }
}

