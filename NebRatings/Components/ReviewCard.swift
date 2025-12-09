//
//  ReviewCard.swift
//  NebRatings
//
//  Created by Cole Whaley on 11/29/25.
//

import SwiftUI

struct TruncatedTextHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

struct FullTextHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

struct ReviewCard: View {
    let review: Review
    var showTitle: String?
    var showCategory: Show.Category?
    var isOwnReview: Bool = false
    var onTap: (() -> Void)? = nil
    @Environment(\.colorScheme) var colorScheme
    @State private var truncatedHeight: CGFloat = 0
    @State private var fullHeight: CGFloat = 0
    
    private let fixedCardHeight: CGFloat = 180
    private let commentLineLimit = 3
    
    private var isTruncated: Bool {
        truncatedHeight > 0 && fullHeight > 0 && fullHeight > truncatedHeight
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let showTitle {
                HStack(spacing: 8) {
                    if let showCategory {
                        Text(showCategory.rawValue.uppercased())
                            .font(.caption.bold())
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(showCategory.badgeColor.opacity(0.15), in: Capsule())
                            .foregroundStyle(showCategory.badgeColor)
                    }
                    Text(showTitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            // Author name on its own line
            HStack(spacing: 6) {
                Text(review.author)
                    .font(isOwnReview ? .headline.bold() : .headline)
                    .foregroundStyle(isOwnReview ? .purple : .primary)
                if isOwnReview {
                    Text("(You)")
                        .font(.caption)
                        .foregroundStyle(.purple)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.purple.opacity(0.15), in: Capsule())
                }
            }
            
            // Rating on its own line
            HStack {
                Spacer()
                NebRatingView(rating: review.nebRating)
            }
            
            // Comment with truncation indicator
            VStack(alignment: .leading, spacing: 4) {
                // Visible truncated text
                Text(review.comment)
                    .font(.body)
                    .foregroundStyle(.primary)
                    .lineLimit(commentLineLimit)
                    .multilineTextAlignment(.leading)
                
                // Show "Tap to read more" only if text is truncated
                if isTruncated {
                    HStack {
                        Spacer()
                        Text("Tap to read more")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .italic()
                    }
                }
            }
            .background(
                // Measure full text height vs truncated
                ZStack(alignment: .topLeading) {
                    Text(review.comment)
                        .font(.body)
                        .lineLimit(nil)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity)
                        .opacity(0)
                        .background(
                            GeometryReader { fullGeo in
                                Color.clear
                                    .preference(key: FullTextHeightKey.self, value: fullGeo.size.height)
                            }
                        )
                    
                    Text(review.comment)
                        .font(.body)
                        .lineLimit(commentLineLimit)
                        .frame(maxWidth: .infinity)
                        .opacity(0)
                        .background(
                            GeometryReader { truncatedGeo in
                                Color.clear
                                    .preference(key: TruncatedTextHeightKey.self, value: truncatedGeo.size.height)
                            }
                        )
                }
                .hidden()
            )
            .onPreferenceChange(TruncatedTextHeightKey.self) { height in
                truncatedHeight = height
            }
            .onPreferenceChange(FullTextHeightKey.self) { height in
                fullHeight = height
            }
            
            Text(review.timestamp.formatted(date: .abbreviated, time: .shortened))
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding()
        .frame(height: fixedCardHeight, alignment: .top)
        .background {
            Group {
                if isOwnReview {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.purple.opacity(0.08))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(.thinMaterial)
                        )
                } else {
                    // Use a visible background that contrasts with white in light mode
                    let backgroundColor = colorScheme == .light 
                    ? Color.gray.opacity(0.15) // Light gray for light mode
                        : Color(uiColor: UIColor.secondarySystemBackground)  // System background for dark mode
                    RoundedRectangle(cornerRadius: 16)
                        .fill(backgroundColor)
                }
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(
                    isOwnReview 
                        ? Color.purple.opacity(0.3) 
                        : Color.clear,
                    lineWidth: isOwnReview ? 2 : 0
                )
        )
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .simultaneousGesture(
            TapGesture()
                .onEnded { _ in
                    onTap?()
                }
        )
    }
    
}

