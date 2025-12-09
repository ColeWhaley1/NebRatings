//
//  ExpandedReviewView.swift
//  NebRatings
//
//  Created by Cole Whaley on 11/29/25.
//

import SwiftUI

struct ExpandedReviewView: View {
    let review: Review
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Header
                    VStack(alignment: .leading, spacing: 12) {
                        // Author and rating
                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(review.author)
                                    .font(.title2.bold())
                                    .foregroundStyle(.primary)
                                
                                Text(review.showTitle)
                                    .font(.headline)
                                    .foregroundStyle(.secondary)
                            }
                            
                            Spacer()
                            
                            NebRatingView(rating: review.nebRating)
                        }
                        
                        // Timestamp
                        Text(review.timestamp.formatted(date: .complete, time: .shortened))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.bottom, 8)
                    
                    Divider()
                    
                    // Full comment
                    Text(review.comment)
                        .font(.body)
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding()
            }
            .navigationTitle("Review")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

