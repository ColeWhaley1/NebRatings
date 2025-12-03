//
//  NebRatingView.swift
//  NebRatings
//
//  Created by Cole Whaley on 11/29/25.
//

import SwiftUI

struct NebRatingView: View {
    let rating: Double
    private let maxNebs = 5

    var body: some View {
        HStack(spacing: 6) {
            ForEach(1...maxNebs, id: \.self) { index in
                let filled = index <= Int(round(rating))
                Image(systemName: filled ? "moon.stars.fill" : "moon.stars")
                    .foregroundStyle(filled ? Color.purple : Color(.tertiaryLabel))
            }
            Text(String(format: "%.1f", rating))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
        }
        .accessibilityLabel("\(rating, specifier: "%.1f") out of \(maxNebs) nebs")
    }
}



