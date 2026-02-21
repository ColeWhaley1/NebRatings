//
//  ShowDetailListSeasonPicker.swift
//  NebRatings
//
//  Custom season selection UI for list picker. No native Toggle—tappable rows only.
//

import SwiftUI

/// A single tappable option row (e.g. "Entire show" or "Season 1")
struct ShowDetailListSeasonOptionRow: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(isSelected ? .blue : .secondary)
                .font(.body)
            
            Text(title)
                .font(.body)
                .foregroundStyle(.primary)
            
            Spacer(minLength: 0)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .onTapGesture {
            action()
        }
    }
}

/// Season selection block for a single list (when show is a series)
struct ShowDetailListSeasonPicker: View {
    let numberOfSeasons: Int
    let currentSeasons: [Int]?
    let onSeasonsChanged: ([Int]?) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ShowDetailListSeasonOptionRow(
                title: "Entire show",
                isSelected: currentSeasons == nil,
                action: {
                    if currentSeasons == nil {
                        onSeasonsChanged([])
                    } else {
                        onSeasonsChanged(nil)
                    }
                }
            )
            
            if currentSeasons != nil {
                ForEach(1...numberOfSeasons, id: \.self) { seasonNum in
                    ShowDetailListSeasonOptionRow(
                        title: "Season \(seasonNum)",
                        isSelected: (currentSeasons ?? []).contains(seasonNum),
                        action: {
                            var current = currentSeasons ?? []
                            if current.contains(seasonNum) {
                                current.removeAll { $0 == seasonNum }
                                onSeasonsChanged(current.isEmpty ? nil : current.sorted())
                            } else {
                                current.append(seasonNum)
                                onSeasonsChanged(current.sorted())
                            }
                        }
                    )
                }
            }
        }
        .background(Color(.secondarySystemGroupedBackground))
    }
}
