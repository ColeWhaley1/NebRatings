//
//  ActorFilmographyView.swift
//  NebRatings
//
//  The movies and TV shows an actor appeared in. Pushed on demand when a cast
//  member is tapped on the Cast screen — the combined-credits request fires
//  here, not with the cast list. Each poster pushes that title's detail page,
//  resolving against the ambient `navigationDestination(for: Show.self)` the
//  same way the "You may also like…" recommendations do.
//

import SwiftUI

struct ActorFilmographyView: View {
    let person: CastMember

    @Environment(NebRatingsStore.self) private var store
    @State private var titles: [Show] = []
    @State private var isLoading = true
    /// Drives the push to a tapped title. Uses `navigationDestination(item:)`
    /// for the same reason CastView does: this screen is reached through
    /// binding-driven pushes, and a value-based `NavigationLink` at this depth
    /// resolves against the far-away root destination instead of pushing a new
    /// detail page — which just re-routed to the page already on screen.
    @State private var selectedShow: Show?

    // `.top` so a one-line title next to a two-line one doesn't centre its
    // card and knock the posters out of horizontal alignment.
    private let columns = [GridItem(.adaptive(minimum: 100), spacing: 14, alignment: .top)]

    var body: some View {
        Group {
            if isLoading {
                ProgressView("Loading filmography…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if titles.isEmpty {
                ContentUnavailableView(
                    "No titles found",
                    systemImage: "film.stack",
                    description: Text("TMDB doesn't list any movies or shows for \(person.name) yet.")
                )
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 18) {
                        ForEach(titles) { show in
                            Button {
                                selectedShow = show
                            } label: {
                                posterCard(show)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(16)
                }
            }
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(person.name)
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(item: $selectedShow) { show in
            ShowDetailView(show: show)
        }
        .task {
            titles = await store.fetchFilmography(personID: person.id)
            // Warm posters up front so the grid fills without pop-in.
            ImageCache.shared.prefetch(titles.map(\.posterURL))
            isLoading = false
        }
    }

    private func posterCard(_ show: Show) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Group {
                if let posterURL = show.posterURL {
                    AsyncImageView(urlString: posterURL)
                        // `.fit` (not `.fill`): the column width bounds the box
                        // and the height derives from it. AsyncImageView already
                        // fills + clips internally, so the art still goes
                        // edge-to-edge without overflowing the column.
                        .aspectRatio(2/3, contentMode: .fit)
                } else {
                    ZStack {
                        Rectangle().fill(Color.gray.opacity(0.2))
                        Image(systemName: show.category == .movie ? "film" : "tv")
                            .font(.title)
                            .foregroundStyle(.secondary)
                    }
                    .aspectRatio(2/3, contentMode: .fit)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(Color(uiColor: .separator), lineWidth: 0.5)
            )

            // `reservesSpace` keeps every card exactly two title lines tall, so
            // one- and two-line titles don't produce ragged card heights.
            Text(show.title)
                .font(.caption.bold())
                .foregroundStyle(.primary)
                .lineLimit(2, reservesSpace: true)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(String(show.year))
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
