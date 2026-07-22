//
//  TopGenreView.swift
//  NebRatings
//
//  Profile card showing a user's most-reviewed genre. Reads the persisted
//  `topGenre` off the profile (maintained incrementally on each review write),
//  so rendering it costs no TMDB lookups. Mirrors CriticGaugeView's card style.
//

import SwiftUI

struct TopGenreView: View {
    /// The user's most-reviewed genre, or nil if there's no genre data yet.
    let genre: String?
    let isLoading: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "film.fill")
                    .foregroundStyle(.secondary)
                Text("Top Genre")
                    .font(.subheadline.bold())
                    .foregroundStyle(.secondary)
                Spacer()
            }

            if isLoading {
                HStack {
                    ProgressView().scaleEffect(0.8)
                    Text("Tallying…")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, 12)
            } else if let genre {
                HStack(spacing: 12) {
                    Text(Self.emoji(for: genre))
                        .font(.system(size: 34))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(genre)
                            .font(.title3.bold())
                        Text("Most-reviewed genre")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
            } else {
                Text("Not enough reviews yet.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 12)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.gray.opacity(0.08))
        )
    }

    /// Maps TMDB genre names (both movie and TV variants) to a representative
    /// emoji. Falls back to a clapperboard for anything unmapped.
    static func emoji(for genre: String) -> String {
        switch genre {
        case "Action", "Action & Adventure": return "💥"
        case "Adventure": return "🗺️"
        case "Animation": return "🎨"
        case "Comedy": return "😂"
        case "Crime": return "🔪"
        case "Documentary": return "🎥"
        case "Drama": return "🎭"
        case "Family": return "👨‍👩‍👧‍👦"
        case "Fantasy": return "🧙"
        case "History": return "📜"
        case "Horror": return "👻"
        case "Kids": return "🧒"
        case "Music": return "🎵"
        case "Mystery": return "🕵️"
        case "News": return "📰"
        case "Reality": return "📺"
        case "Romance": return "❤️"
        case "Science Fiction", "Sci-Fi", "Sci-Fi & Fantasy": return "🚀"
        case "Soap": return "🫧"
        case "Talk": return "🎙️"
        case "Thriller": return "😱"
        case "TV Movie": return "📺"
        case "War", "War & Politics": return "⚔️"
        case "Western": return "🤠"
        default: return "🎬"
        }
    }
}

#Preview {
    VStack(spacing: 16) {
        TopGenreView(genre: "Science Fiction", isLoading: false)
        TopGenreView(genre: "Comedy", isLoading: false)
        TopGenreView(genre: "War & Politics", isLoading: false)
        TopGenreView(genre: nil, isLoading: false)
        TopGenreView(genre: nil, isLoading: true)
    }
    .padding()
}
