//
//  CastView.swift
//  NebRatings
//
//  Top-billed cast for a movie or TV show: headshot, actor name, and
//  character, in billing order. Pushed on demand from the detail page's
//  "Cast & Crew" row — the credits request fires here, not with the page.
//

import SwiftUI

struct CastView: View {
    let show: Show

    @Environment(NebRatingsStore.self) private var store
    @State private var cast: [CastMember] = []
    @State private var isLoading = true

    private let columns = [GridItem(.adaptive(minimum: 104), spacing: 14)]

    var body: some View {
        Group {
            if isLoading {
                ProgressView("Rolling credits…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if cast.isEmpty {
                ContentUnavailableView(
                    "No cast information",
                    systemImage: "person.2.slash",
                    description: Text("TMDB doesn't have cast details for this title yet.")
                )
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 18) {
                        ForEach(cast) { member in
                            castCard(member)
                        }
                    }
                    .padding(16)
                }
            }
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Cast")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            cast = await store.fetchCast(for: show)
            isLoading = false
        }
    }

    private func castCard(_ member: CastMember) -> some View {
        VStack(spacing: 6) {
            ZStack {
                if let profileURL = member.profileURL {
                    AsyncImageView(urlString: profileURL)
                } else {
                    Circle()
                        .fill(Color.gray.opacity(0.2))
                    Image(systemName: "person.fill")
                        .font(.title)
                        .foregroundStyle(Color.secondary)
                }
            }
            .frame(width: 88, height: 88)
            .clipShape(Circle())
            .overlay(
                Circle().strokeBorder(Color(uiColor: .separator), lineWidth: 0.5)
            )

            VStack(spacing: 1) {
                Text(member.name)
                    .font(.caption.bold())
                    .foregroundStyle(Color.primary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                if let character = member.character, !character.isEmpty {
                    Text(character)
                        .font(.caption2)
                        .foregroundStyle(Color.secondary)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                }
            }
            // Uniform text block height keeps grid rows aligned even when
            // names/characters wrap differently.
            .frame(height: 58, alignment: .top)
        }
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    NavigationStack {
        CastView(show: Show.previewData[0])
            .environment(NebRatingsStore())
    }
}
