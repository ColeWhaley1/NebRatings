//
//  EditProfileView.swift
//  NebRatings
//
//  Sheet for editing the extended profile: bio, favorite genres (max 5),
//  and hand-picked favorite movie / TV show. Username + avatar keep their
//  existing dedicated editors on ProfileView.
//

import SwiftUI

struct EditProfileView: View {
    @Environment(NebRatingsStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var bio: String = ""
    @State private var selectedGenres: [String] = []
    @State private var favoriteMovie: FavoriteTitle?
    @State private var favoriteShow: FavoriteTitle?

    @State private var pickingCategory: Show.Category?
    @State private var isSaving = false
    @State private var saveError: String?

    private let bioLimit = 160

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Tell people what you're about…", text: $bio, axis: .vertical)
                        .lineLimit(3...6)
                        .onChange(of: bio) { _, newValue in
                            if newValue.count > bioLimit {
                                bio = String(newValue.prefix(bioLimit))
                            }
                        }
                } header: {
                    Text("Bio")
                } footer: {
                    Text("\(bio.count)/\(bioLimit)")
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }

                Section {
                    GenreChipsPicker(selection: $selectedGenres)
                } header: {
                    Text("Favorite Genres")
                } footer: {
                    Text("Pick up to \(GenreCatalog.maxFavorites). These personalize your Discover tab.")
                }

                Section("Favorites") {
                    favoriteRow(
                        slotLabel: "Favorite Movie",
                        icon: "film",
                        current: favoriteMovie,
                        category: .movie,
                        clear: { favoriteMovie = nil }
                    )
                    favoriteRow(
                        slotLabel: "Favorite TV Show",
                        icon: "tv",
                        current: favoriteShow,
                        category: .series,
                        clear: { favoriteShow = nil }
                    )
                }

                if let saveError {
                    Section {
                        Text(saveError)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Edit Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .disabled(isSaving)
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isSaving {
                        ProgressView()
                    } else {
                        Button("Save") {
                            Task { await save() }
                        }
                    }
                }
            }
            .sheet(item: $pickingCategory) { category in
                FavoriteTitleSearchSheet(category: category) { pick in
                    switch category {
                    case .movie: favoriteMovie = pick
                    case .series: favoriteShow = pick
                    }
                }
                .environment(store)
            }
            .onAppear {
                let profile = store.currentUser
                bio = profile?.bio ?? ""
                selectedGenres = profile?.favoriteGenres ?? []
                favoriteMovie = profile?.favoriteMovie
                favoriteShow = profile?.favoriteShow
            }
        }
    }

    @ViewBuilder
    private func favoriteRow(slotLabel: String,
                             icon: String,
                             current: FavoriteTitle?,
                             category: Show.Category,
                             clear: @escaping () -> Void) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .foregroundStyle(.purple)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(slotLabel)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(current?.title ?? "None chosen")
                    .font(.body)
                    .foregroundStyle(current == nil ? .secondary : .primary)
                    .lineLimit(1)
            }
            Spacer()
            if current != nil {
                Button {
                    clear()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            Button(current == nil ? "Choose" : "Change") {
                pickingCategory = category
            }
            .font(.subheadline)
            .buttonStyle(.bordered)
            .tint(.purple)
        }
    }

    private func save() async {
        isSaving = true
        saveError = nil
        do {
            let profile = store.currentUser
            let trimmedBio = bio.trimmingCharacters(in: .whitespacesAndNewlines)

            // Only write fields that changed — each write refetches the
            // profile, so skipping no-ops keeps saving snappy.
            if trimmedBio != (profile?.bio ?? "") {
                try await store.updateBio(trimmedBio.isEmpty ? nil : trimmedBio)
            }
            if selectedGenres != (profile?.favoriteGenres ?? []) {
                try await store.updateFavoriteGenres(selectedGenres)
            }
            if favoriteMovie != profile?.favoriteMovie {
                try await store.updateFavoriteTitle(favoriteMovie, field: .movie)
            }
            if favoriteShow != profile?.favoriteShow {
                try await store.updateFavoriteTitle(favoriteShow, field: .show)
            }
            dismiss()
        } catch {
            saveError = "Couldn't save changes. Please try again."
        }
        isSaving = false
    }
}

// MARK: - Genre picker

/// Tappable chip grid; selection order is preserved (first tapped = first
/// shown on the profile). Caps at GenreCatalog.maxFavorites.
private struct GenreChipsPicker: View {
    @Binding var selection: [String]

    var body: some View {
        FlowLayout(spacing: 8) {
            ForEach(GenreCatalog.selectableGenres, id: \.self) { genre in
                let isSelected = selection.contains(genre)
                let isDisabled = !isSelected && selection.count >= GenreCatalog.maxFavorites
                Button {
                    if isSelected {
                        selection.removeAll { $0 == genre }
                    } else if selection.count < GenreCatalog.maxFavorites {
                        selection.append(genre)
                    }
                } label: {
                    Text(genre)
                        .font(.caption.bold())
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(
                            isSelected ? Color.purple : Color.purple.opacity(0.1),
                            in: Capsule()
                        )
                        .foregroundStyle(isSelected ? .white : (isDisabled ? .secondary : .purple))
                }
                .buttonStyle(.plain)
                .disabled(isDisabled)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Favorite title search

/// Search-and-pick sheet for the favorite movie/show slots. Uses the
/// detached search so the Discover tab's state is untouched.
private struct FavoriteTitleSearchSheet: View {
    let category: Show.Category
    let onPick: (FavoriteTitle) -> Void

    @Environment(NebRatingsStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var query = ""
    @State private var results: [Show] = []
    @State private var isSearching = false
    @State private var searchTask: Task<Void, Never>?

    var body: some View {
        NavigationStack {
            List {
                if isSearching {
                    HStack {
                        Spacer()
                        ProgressView()
                        Spacer()
                    }
                } else if results.isEmpty && !query.isEmpty {
                    Text("No results")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(results) { show in
                        Button {
                            onPick(FavoriteTitle(
                                id: show.id,
                                title: show.title,
                                posterURL: show.posterURL,
                                category: show.category
                            ))
                            dismiss()
                        } label: {
                            ShowRow(show: show)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .navigationTitle(category == .movie ? "Pick a Movie" : "Pick a TV Show")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $query, prompt: category == .movie ? "Search movies" : "Search TV shows")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .onChange(of: query) { _, _ in
                performSearch()
            }
        }
    }

    private func performSearch() {
        searchTask?.cancel()
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else {
            results = []
            isSearching = false
            return
        }
        isSearching = true
        searchTask = Task {
            try? await Task.sleep(nanoseconds: 300_000_000)
            guard !Task.isCancelled else { return }
            let found = await store.searchShowsDetached(query: trimmed, category: category)
            guard !Task.isCancelled else { return }
            results = found
            isSearching = false
        }
    }
}

#Preview {
    EditProfileView()
        .environment(NebRatingsStore())
}
