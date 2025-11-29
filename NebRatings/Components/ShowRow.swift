//
//  ShowRow.swift
//  NebRatings
//
//  Created by Cole Whaley on 11/29/25.
//

import SwiftUI

struct ShowRow: View {
    let show: Show

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(show.title)
                    .font(.headline)
                Spacer()
                Text(show.category.rawValue)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(show.category.badgeColor.opacity(0.15), in: Capsule())
                    .foregroundStyle(show.category.badgeColor)
            }
            Text(show.synopsis)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(2)
            if show.averageNebs > 0 {
                HStack(spacing: 8) {
                    NebRatingView(rating: show.averageNebs)
                    Text("\(show.reviews.count) reviews")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 2)
            }
        }
        .padding(.vertical, 4)
    }
}

