//
//  ShowDetailListPickerRow.swift
//  NebRatings
//
//  Movies: multiselect (checkmark, tap to toggle). Series: dropdown menu.
//

import SwiftUI

/// Selection for one list in the picker
enum ListRowSelection: Equatable {
    case notInList
    case inList(seasons: [Int]?)  // nil = all seasons, [1,2] = specific
}

struct ShowDetailListPickerRow: View {
    let list: ShowList
    let isSeries: Bool
    let numberOfSeasons: Int
    let selection: ListRowSelection
    let onSelectionChanged: (ListRowSelection) -> Void
    
    private var isSelected: Bool {
        if case .inList = selection { return true }
        return false
    }
    
    private var isAllSeasonsSelected: Bool {
        if case .inList(let s) = selection { return s == nil }
        return false
    }
    
    private func isSeasonSelected(_ num: Int) -> Bool {
        if case .inList(let s) = selection, let seasons = s, seasons.contains(num) { return true }
        return false
    }
    
    var body: some View {
        if isSeries && numberOfSeasons > 0 {
            seriesRow
        } else {
            movieRow
        }
    }
    
    /// Movies: multiselect style - checkmark + tap to toggle
    private var movieRow: some View {
        Button(action: {
            onSelectionChanged(isSelected ? .notInList : .inList(seasons: nil))
        }) {
            HStack(spacing: 12) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? .blue : .secondary)
                    .font(.title3)
                
                HStack(spacing: 6) {
                    Text(list.name)
                        .font(.body)
                        .foregroundStyle(.primary)
                    if list.isDefault {
                        Text("Default")
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.purple.opacity(0.15), in: Capsule())
                            .foregroundStyle(.purple)
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
    
    /// Series: dropdown menu for Not in list / All seasons / individual seasons
    private var seriesRow: some View {
        HStack(spacing: 12) {
            HStack(spacing: 6) {
                Text(list.name)
                    .font(.body)
                    .foregroundStyle(.primary)
                if list.isDefault {
                    Text("Default")
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.purple.opacity(0.15), in: Capsule())
                        .foregroundStyle(.purple)
                }
            }
            
            Spacer(minLength: 8)
            
            Menu {
                Button {
                    onSelectionChanged(.notInList)
                } label: {
                    menuItemLabel(title: "Not in list", isSelected: selection == .notInList)
                }
                
                Divider()
                Button {
                    onSelectionChanged(.inList(seasons: nil))
                } label: {
                    menuItemLabel(title: "All seasons", isSelected: isAllSeasonsSelected)
                }
                ForEach(1...numberOfSeasons, id: \.self) { num in
                    Button {
                        onSelectionChanged(.inList(seasons: [num]))
                    } label: {
                        menuItemLabel(title: "Season \(num)", isSelected: isSeasonSelected(num))
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Text(seriesDropdownLabel)
                        .font(.subheadline)
                        .foregroundStyle(selection == .notInList ? .secondary : .primary)
                        .lineLimit(1)
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(.tertiarySystemFill))
                )
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .animation(.none, value: seriesDropdownLabel)
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    @ViewBuilder
    private func menuItemLabel(title: String, isSelected: Bool) -> some View {
        HStack {
            Text(title)
            if isSelected {
                Image(systemName: "checkmark")
                    .foregroundStyle(.blue)
            }
        }
    }
    
    private var seriesDropdownLabel: String {
        switch selection {
        case .notInList:
            return "Not in list"
        case .inList(let seasons):
            if let s = seasons, !s.isEmpty {
                let sorted = s.sorted()
                return sorted.count == 1 ? "Season \(sorted[0])" : "Seasons \(sorted.map { String($0) }.joined(separator: ", "))"
            }
            return "All seasons"
        }
    }
}
