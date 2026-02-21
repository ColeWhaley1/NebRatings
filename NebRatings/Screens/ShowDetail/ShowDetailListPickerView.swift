//
//  ShowDetailListPickerView.swift
//  NebRatings
//
//  Add to list button and list picker sheet. For series: dropdown per list for season selection.
//

import SwiftUI

struct ShowDetailAddToListButton: View {
    @Environment(NebRatingsStore.self) private var store: NebRatingsStore
    let displayShow: Show
    @Binding var draftListSelections: [String: [Int]?]
    @Binding var showingListPicker: Bool
    
    var body: some View {
        let listsContainingShow = store.showLists.filter { list in
            list.contains(show: displayShow)
        }
        let count = listsContainingShow.count
        
        return HStack(spacing: 8) {
            Button {
                Task { @MainActor in
                    let listsWithShow = store.showLists.filter { $0.contains(show: displayShow) }
                    if listsWithShow.isEmpty {
                        await store.loadUserLists()
                    }
                    var selections: [String: [Int]?] = [:]
                    for list in store.showLists.filter({ $0.contains(show: displayShow) }) {
                        let ref = list.showReferences.first(where: {
                            $0.id == displayShow.id && $0.category == displayShow.category
                        }) ?? list.showReferences.first(where: { $0.id == displayShow.id })
                        if let ref = ref {
                            selections[list.id] = ref.seasons
                        }
                    }
                    draftListSelections = selections
                    showingListPicker = true
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: count > 0
                          ? (listsContainingShow.first(where: { $0.isDefault }) != nil ? "bookmark.fill" : "list.bullet.rectangle")
                          : "plus.circle")
                        .foregroundStyle(.primary)
                        .font(.body)
                        .symbolRenderingMode(.hierarchical)
                        .frame(width: 20, height: 20)
                    
                    Group {
                        if count > 0 {
                            if count == 1, let list = listsContainingShow.first {
                                Text("In \"\(list.name)\"")
                            } else {
                                Text("In \(count) lists")
                            }
                        } else {
                            Text("Add to List")
                        }
                    }
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                }
                .contentShape(Rectangle())
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct ShowDetailListPickerSheet: View {
    @Environment(NebRatingsStore.self) private var store: NebRatingsStore
    let displayShow: Show
    @Binding var showingListPicker: Bool
    let initialSelections: [String: [Int]?]
    let onDone: ([String: [Int]?]) async -> Void
    
    @State private var selections: [String: [Int]?] = [:]
    
    private var isSeries: Bool { displayShow.category == .series }
    private var numberOfSeasons: Int { displayShow.numberOfSeasons ?? 0 }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    ForEach(store.showLists) { list in
                        ShowDetailListPickerRow(
                            list: list,
                            isSeries: isSeries,
                            numberOfSeasons: numberOfSeasons,
                            selection: selections.keys.contains(list.id)
                                ? .inList(seasons: selections[list.id] ?? nil)
                                : .notInList,
                            onSelectionChanged: { newSel in
                                var u = selections
                                switch newSel {
                                case .notInList:
                                    u.removeValue(forKey: list.id)
                                case .inList(let seasons):
                                    u[list.id] = seasons
                                }
                                selections = u
                            }
                        )
                        
                        if list.id != store.showLists.last?.id {
                            Divider()
                                .padding(.leading, 16)
                        }
                    }
                }
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal, 16)
            }
            .background(Color(.systemGroupedBackground))
            .scrollContentBackground(.hidden)
            .navigationTitle("Add to Lists")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showingListPicker = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        Task { @MainActor in
                            await onDone(selections)
                            showingListPicker = false
                        }
                    }
                }
            }
            .onAppear {
                // Prefer store as source of truth: SwiftUI can pass stale initialSelections on first open
                // (e.g. before loadUserLists commits); store reflects the authoritative list state.
                var fromStore: [String: [Int]?] = [:]
                for list in store.showLists.filter({ $0.contains(show: displayShow) }) {
                    let ref = list.showReferences.first(where: {
                        $0.id == displayShow.id && $0.category == displayShow.category
                    }) ?? list.showReferences.first(where: { $0.id == displayShow.id })
                    if let ref = ref {
                        fromStore[list.id] = ref.seasons
                    }
                }
                selections = fromStore.isEmpty ? initialSelections : fromStore
            }
        }
    }
}
