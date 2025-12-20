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
        Text(String(format: "%.1f", rating))
            .font(.title2.bold()) // Larger and bolder for emphasis
            .foregroundStyle(.primary) // Primary color instead of secondary for visibility
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.orange.opacity(0.2)) // Orange background to stand out
                    .shadow(color: .black.opacity(0.15), radius: 3, x: 0, y: 2)
            )
            .accessibilityLabel("\(rating, specifier: "%.1f") out of \(maxNebs) nebs")
    }
}



