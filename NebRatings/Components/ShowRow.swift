//
//  ShowRow.swift
//  NebRatings
//
//  Created by Cole Whaley on 11/29/25.
//

import SwiftUI

struct ShowRow: View {
    let show: Show
    /// Optional label for series in lists, e.g. "Season 1" or "Seasons 1, 2, 3"
    var seasonsLabel: String? = nil
    
    private var yearFormatted: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .none
        formatter.usesGroupingSeparator = false
        return formatter.string(from: NSNumber(value: show.year)) ?? "\(show.year)"
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Poster thumbnail - consistent width whether poster exists or not
            Group {
                if let posterURL = show.posterURL {
                    AsyncImageView(urlString: posterURL)
                        .frame(width: 80, height: 120)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.gray.opacity(0.2), lineWidth: 0.5)
                        )
                } else {
                    // Placeholder to maintain consistent spacing
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.gray.opacity(0.1))
                        .frame(width: 80, height: 120)
                        .overlay(
                            Image(systemName: "photo")
                                .foregroundStyle(.gray.opacity(0.3))
                                .font(.title2)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.gray.opacity(0.2), lineWidth: 0.5)
                        )
                }
            }
            
            // Content
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(show.title)
                            .font(.headline)
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                        if let seasonsLabel {
                            Text(seasonsLabel)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                    Text(show.category.rawValue)
                        .font(.subheadline)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(show.category.badgeColor.opacity(0.15), in: Capsule())
                        .foregroundStyle(show.category.badgeColor)
                }
                
                Text(show.synopsis)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                
                HStack(spacing: 8) {
                    HStack(spacing: 4) {
                        Image(systemName: "calendar")
                        Text(yearFormatted)
                    }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    Spacer()
                    if show.averageNebs > 0 {
                        NebRatingView(rating: show.averageNebs)
                        Text("\(show.reviews.count)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.top, 2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 4)
    }
}

#Preview("With Poster") {
    let show = Show.previewData[0] // Inception with poster
    
    return List {
        ShowRow(show: show)
    }
    .listStyle(.insetGrouped)
}

#Preview("Without Poster") {
    let show = Show.previewData[4] // The Matrix without poster
    
    return List {
        ShowRow(show: show)
    }
    .listStyle(.insetGrouped)
}

#Preview("TV Show") {
    let show = Show.previewData[1] // Breaking Bad
    
    return List {
        ShowRow(show: show)
    }
    .listStyle(.insetGrouped)
}

#Preview("Multiple Rows") {
    return List {
        ForEach(Show.previewData.prefix(3)) { show in
            ShowRow(show: show)
        }
    }
    .listStyle(.insetGrouped)
}

