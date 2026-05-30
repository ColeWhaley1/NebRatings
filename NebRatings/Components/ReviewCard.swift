//
//  ReviewCard.swift
//  NebRatings
//
//  Created by Cole Whaley on 11/29/25.
//

import SwiftUI

// Modifier to conditionally add tap gesture only when onTap is provided
struct ConditionalTapGestureModifier: ViewModifier {
    let onTap: (() -> Void)?
    
    func body(content: Content) -> some View {
        if let onTap = onTap {
            content
                .contentShape(Rectangle())
                .onTapGesture {
                    onTap()
                }
        } else {
            content
                .contentShape(Rectangle())
        }
    }
}

struct ReviewCard: View {
    let review: Review
    var showTitle: String?
    var showCategory: Show.Category?
    var isOwnReview: Bool = false
    var authorAvatarEmoji: String? = nil
    var isFriend: Bool = false
    var onTap: (() -> Void)? = nil
    var useLighterBackground: Bool = false // For Reviews tab to add contrast
    @Environment(\.colorScheme) var colorScheme

    private let fixedCardHeight: CGFloat = 220 // Increased for better spacing
    private let commentLineLimit = 3
    
    private var backgroundShape: some View {
        Group {
            if isOwnReview {
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.purple.opacity(0.08))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(.thinMaterial)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(
                                Color.purple.opacity(0.3),
                                lineWidth: 2
                            )
                    )
            } else {
                // Use a visible background that contrasts with white in light mode
                // In Reviews tab, use slightly lighter background for better contrast
                let backgroundColor: Color = {
                    if useLighterBackground {
                        // Reviews tab - slightly lighter for contrast
                        return colorScheme == .light 
                            ? Color.gray.opacity(0.2) // Slightly lighter gray for light mode
                            : Color(uiColor: UIColor.tertiarySystemBackground) // Tertiary background for dark mode
                    } else {
                        // ShowDetailView - same as list background
                        return colorScheme == .light 
                            ? Color.gray.opacity(0.15) // Light gray for light mode
                            : Color(uiColor: UIColor.secondarySystemBackground)  // System background for dark mode
                    }
                }()
                RoundedRectangle(cornerRadius: 16)
                    .fill(backgroundColor)
            }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
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

                    // Show season info if this is a season-specific review
                    if let season = review.season {
                        Text("S\(season)")
                            .font(.caption.bold())
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.secondary.opacity(0.15), in: Capsule())
                            .foregroundStyle(.secondary)
                    }
                }
            }

            // Author avatar, name, and rating on the same line
            HStack(spacing: 8) {
                // Avatar — another quick way to recognize who wrote the review
                AvatarView(emoji: authorAvatarEmoji, size: 34)

                // Author name with ellipsis if too long
                HStack(spacing: 6) {
                    Text(review.author)
                        .font(isOwnReview ? .headline.bold() : .headline)
                        .foregroundStyle(isOwnReview ? .purple : .primary)
                        .lineLimit(1)
                    if isOwnReview {
                        Text("You")
                            .font(.caption)
                            .foregroundStyle(.purple)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.purple.opacity(0.15), in: Capsule())
                    } else if isFriend {
                        Text("Friend")
                            .font(.caption.bold())
                            .foregroundStyle(.teal)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.teal.opacity(0.18), in: Capsule())
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                // Rating fixed to right
                NebRatingView(rating: review.nebRating, isOwnReview: isOwnReview)
            }
            
            // Comment - ellipsis will appear automatically when truncated
            Text(review.comment)
                .font(.body)
                .foregroundStyle(.primary)
                .lineLimit(commentLineLimit)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            // Spacer to push timestamp to bottom
            Spacer()
            
            // Timestamp fixed to bottom left with padding
            Text(review.timestamp.formatted(date: .abbreviated, time: .shortened))
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.top, 14)
        .padding(.bottom, 14)
        .frame(height: fixedCardHeight, alignment: .top)
        .background(backgroundShape)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .frame(maxWidth: .infinity, alignment: .leading)
        .modifier(ConditionalTapGestureModifier(onTap: onTap))
    }

}

#Preview("Short Text - Light") {
    let shortReview = Review(
        showID: 123,
        showTitle: "The Matrix",
        showCategory: .movie,
        author: "john_doe",
        comment: "Amazing movie!",
        nebRating: 4.5,
        timestamp: Date()
    )
    
    return ReviewCard(
        review: shortReview,
        showTitle: "The Matrix",
        showCategory: .movie
    )
    .padding()
    .background(Color(.systemGroupedBackground))
    .preferredColorScheme(.light)
}

#Preview("Short Text - Dark") {
    let shortReview = Review(
        showID: 123,
        showTitle: "The Matrix",
        showCategory: .movie,
        author: "john_doe",
        comment: "Amazing movie!",
        nebRating: 4.5,
        timestamp: Date()
    )
    
    return ReviewCard(
        review: shortReview,
        showTitle: "The Matrix",
        showCategory: .movie
    )
    .padding()
    .background(Color(.systemGroupedBackground))
    .preferredColorScheme(.dark)
}

#Preview("Long Text - Light") {
    let longReview = Review(
        showID: 456,
        showTitle: "The Lord of the Rings: The Fellowship of the Ring",
        showCategory: .movie,
        author: "jane_smith",
        comment: "This is an absolutely fantastic film that completely exceeded my expectations. The cinematography is breathtaking, the story is engaging from start to finish, and the characters are well-developed. I especially loved the attention to detail in the world-building and how each scene contributes to the overall narrative. The acting performances are stellar, and the direction is masterful.",
        nebRating: 5.0,
        timestamp: Date()
    )
    
    return ReviewCard(
        review: longReview,
        showTitle: "The Lord of the Rings: The Fellowship of the Ring",
        showCategory: .movie
    )
    .padding()
    .background(Color(.systemGroupedBackground))
    .preferredColorScheme(.light)
}

#Preview("Long Text - Dark") {
    let longReview = Review(
        showID: 456,
        showTitle: "The Lord of the Rings: The Fellowship of the Ring",
        showCategory: .movie,
        author: "jane_smith",
        comment: "This is an absolutely fantastic film that completely exceeded my expectations. The cinematography is breathtaking, the story is engaging from start to finish, and the characters are well-developed. I especially loved the attention to detail in the world-building and how each scene contributes to the overall narrative. The acting performances are stellar, and the direction is masterful.",
        nebRating: 5.0,
        timestamp: Date()
    )
    
    return ReviewCard(
        review: longReview,
        showTitle: "The Lord of the Rings: The Fellowship of the Ring",
        showCategory: .movie
    )
    .padding()
    .background(Color(.systemGroupedBackground))
    .preferredColorScheme(.dark)
}

#Preview("Own Review - Light") {
    let ownReview = Review(
        showID: 789,
        showTitle: "Inception",
        showCategory: .movie,
        author: "colewhaley",
        comment: "Mind-bending masterpiece!",
        nebRating: 5.0,
        timestamp: Date()
    )
    
    return ReviewCard(
        review: ownReview,
        showTitle: "Inception",
        showCategory: .movie,
        isOwnReview: true
    )
    .padding()
    .background(Color(.systemGroupedBackground))
    .preferredColorScheme(.light)
}

#Preview("Own Review - Dark") {
    let ownReview = Review(
        showID: 789,
        showTitle: "Inception",
        showCategory: .movie,
        author: "colewhaley",
        comment: "Mind-bending masterpiece!",
        nebRating: 5.0,
        timestamp: Date()
    )
    
    return ReviewCard(
        review: ownReview,
        showTitle: "Inception",
        showCategory: .movie,
        isOwnReview: true
    )
    .padding()
    .background(Color(.systemGroupedBackground))
    .preferredColorScheme(.dark)
}

