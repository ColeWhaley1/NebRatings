//
//  ShowDetailHeaderView.swift
//  NebRatings
//
//  Header section for ShowDetailView: poster, metadata, synopsis, genres.
//

import SwiftUI

struct ShowDetailHeaderView: View {
    @Environment(NebRatingsStore.self) private var store: NebRatingsStore
    let displayShow: Show
    @Binding var isProvidersExpanded: Bool
    let communityAverage: Double
    let communityReviewCount: Int
    let yearFormatted: String
    let addToListButton: AnyView
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 16) {
                if displayShow.posterURL != nil {
                    AsyncImageView(urlString: displayShow.posterURL)
                        .frame(width: 100, height: 150)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color(.separator), lineWidth: 1)
                        )
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 6) {
                            Image(systemName: "calendar")
                                .foregroundStyle(.secondary)
                                .font(.subheadline)
                                .frame(width: 20, alignment: .leading)
                            Text(yearFormatted)
                                .foregroundStyle(.primary)
                                .font(.subheadline)
                        }
                        
                        if displayShow.category == .series, let seasons = displayShow.numberOfSeasons, seasons > 0 {
                            HStack(spacing: 6) {
                                Image(systemName: "tv")
                                    .foregroundStyle(.secondary)
                                    .font(.subheadline)
                                    .frame(width: 20, alignment: .leading)
                                Text("\(seasons) \(seasons == 1 ? "season" : "seasons")")
                                    .foregroundStyle(.primary)
                                    .font(.subheadline)
                            }
                        }
                        
                        if !displayShow.watchProviders.isEmpty {
                            if displayShow.watchProviders.count == 1, let provider = displayShow.watchProviders.first {
                                HStack(spacing: 6) {
                                    if let logoURL = provider.logoURL {
                                        AsyncImageView(urlString: logoURL)
                                            .frame(width: 20, height: 20)
                                            .clipShape(RoundedRectangle(cornerRadius: 4))
                                    } else {
                                        Color.clear
                                            .frame(width: 20)
                                    }
                                    Text(provider.name)
                                        .font(.subheadline)
                                        .foregroundStyle(.primary)
                                }
                            } else {
                                DisclosureGroup(isExpanded: $isProvidersExpanded) {
                                    VStack(alignment: .leading, spacing: 8) {
                                        ForEach(displayShow.watchProviders) { provider in
                                            HStack(spacing: 6) {
                                                if let logoURL = provider.logoURL {
                                                    AsyncImageView(urlString: logoURL)
                                                        .frame(width: 24, height: 24)
                                                        .clipShape(RoundedRectangle(cornerRadius: 4))
                                                }
                                                Text(provider.name)
                                                    .font(.subheadline)
                                                    .foregroundStyle(.primary)
                                            }
                                        }
                                    }
                                    .padding(.top, 4)
                                } label: {
                                    HStack(spacing: 6) {
                                        Image(systemName: "play.tv")
                                            .foregroundStyle(.secondary)
                                            .font(.subheadline)
                                            .frame(width: 20, alignment: .leading)
                                        Text("Where to watch")
                                            .font(.subheadline)
                                            .foregroundStyle(.primary)
                                        Text("(\(displayShow.watchProviders.count))")
                                            .font(.subheadline)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                .transaction { transaction in
                                    transaction.animation = nil
                                }
                            }
                        } else if !displayShow.streamingService.isEmpty && displayShow.streamingService != "Various" {
                            HStack(spacing: 6) {
                                Image(systemName: "play.tv")
                                    .foregroundStyle(.secondary)
                                    .font(.subheadline)
                                    .frame(width: 20, alignment: .leading)
                                Text(displayShow.streamingService)
                                    .foregroundStyle(.primary)
                                    .font(.subheadline)
                            }
                        }
                        
                        if let rating = displayShow.rating, rating > 0 {
                            HStack(spacing: 6) {
                                HStack(spacing: 4) {
                                    Text(String(format: "%.1f", rating))
                                        .foregroundStyle(.primary)
                                        .font(.subheadline.bold())
                                    Text("/ 10")
                                        .foregroundStyle(.secondary)
                                        .font(.caption)
                                }
                                Text("Audience Score")
                                    .foregroundStyle(.secondary)
                                    .font(.subheadline.bold())
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        
                        if communityAverage > 0 {
                            VStack(alignment: .leading, spacing: 4) {
                                HStack(alignment: .firstTextBaseline, spacing: 6) {
                                    if let emoji = ShowDetailHelpers.ratingEmoji(for: communityAverage) {
                                        Text(emoji)
                                            .font(.subheadline)
                                    }
                                    HStack(spacing: 4) {
                                        Text(String(format: "%.1f", ShowDetailHelpers.displayedRating(for: communityAverage)))
                                            .foregroundStyle(.primary)
                                            .font(.subheadline.bold())
                                        Text("/ 10")
                                            .foregroundStyle(.secondary)
                                            .font(.caption)
                                    }
                                    Text("Neb Average")
                                        .foregroundStyle(.secondary)
                                        .font(.subheadline.bold())
                                        .fixedSize(horizontal: false, vertical: true)
                                    Text("(\(communityReviewCount))")
                                        .foregroundStyle(.secondary)
                                        .font(.subheadline)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                                .fixedSize(horizontal: false, vertical: true)
                                
                                if let audienceRating = displayShow.rating, audienceRating > 0 {
                                    let nebRatingDisplay = ShowDetailHelpers.displayedRating(for: communityAverage)
                                    let discrepancy = nebRatingDisplay - audienceRating
                                    
                                    if abs(discrepancy) >= 1.0 {
                                        HStack(spacing: 4) {
                                            Image(systemName: discrepancy > 0 ? "arrow.up" : "arrow.down")
                                                .font(.caption2)
                                                .foregroundStyle(discrepancy > 0 ? .green : .orange)
                                            
                                            Text(discrepancy > 0
                                                ? "Rated higher by Neb reviewers"
                                                : "Rated lower by Neb reviewers")
                                                .font(.caption)
                                                .foregroundStyle(discrepancy > 0 ? .green : .orange)
                                        }
                                    }
                                }
                            }
                        }
                        
                        if !store.showLists.isEmpty {
                            addToListButton
                                .padding(.top, 8)
                        }
                    }
                }
            }
            
            Text(displayShow.synopsis)
                .font(.body)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
            
            if !displayShow.genres.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(displayShow.genres, id: \.self) { genre in
                            Text(genre)
                                .font(.caption)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Color.purple.opacity(0.2))
                                .foregroundStyle(.primary)
                                .clipShape(Capsule())
                        }
                    }
                }
            }
            
            if displayShow.tmdbID != nil {
                VStack(alignment: .leading, spacing: 2) {
                    if !displayShow.watchProviders.isEmpty {
                        Text("Streaming data provided by JustWatch")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                    Text("Data provided by TMDB")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                .padding(.top, 4)
            }
        }
    }
}
