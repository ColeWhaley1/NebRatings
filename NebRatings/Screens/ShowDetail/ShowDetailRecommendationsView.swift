//
//  ShowDetailRecommendationsView.swift
//  NebRatings
//
//  Recommendations section for ShowDetailView.
//

import SwiftUI

struct ShowDetailRecommendationsView: View {
    @Environment(NebRatingsStore.self) private var store: NebRatingsStore
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("You may also like...")
                .font(.title3.bold())
                .foregroundStyle(.primary)
            
            if store.isLoadingRecommendations {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding()
            } else if store.recommendations.isEmpty {
                ContentUnavailableView("No recommendations", systemImage: "sparkles", description: Text("Similar shows will appear here."))
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .top, spacing: 16) {
                        ForEach(store.recommendations) { recommendedShow in
                            NavigationLink(value: recommendedShow) {
                                VStack(alignment: .leading, spacing: 8) {
                                    AsyncImageView(urlString: recommendedShow.posterURL)
                                        .frame(width: 120, height: 180)
                                        .clipShape(RoundedRectangle(cornerRadius: 12))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12)
                                                .stroke(Color(.separator), lineWidth: 1)
                                        )
                                    
                                    Text(recommendedShow.title)
                                        .font(.subheadline.bold())
                                        .foregroundStyle(.primary)
                                        .lineLimit(2)
                                        .multilineTextAlignment(.leading)
                                        .frame(width: 120, height: 40, alignment: .topLeading)
                                    
                                    Text(String(recommendedShow.year))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                .frame(width: 120, alignment: .leading)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 4)
                }
            }
        }
    }
}
