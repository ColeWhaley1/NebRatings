//
//  ReviewCard.swift
//  NebRatings
//
//  Created by Cole Whaley on 11/29/25.
//

import SwiftUI
import UIKit  // for UIImpactFeedbackGenerator (double-tap-to-like haptic)

// Modifier to attach single-tap and/or double-tap gestures to the card.
// Order matters: SwiftUI prefers the higher-count tap gesture, but we still
// list `count: 2` first so the disambiguation window is in place before the
// single-tap recognizer.
struct ConditionalTapGestureModifier: ViewModifier {
    let onTap: (() -> Void)?
    let onDoubleTap: (() -> Void)?

    @ViewBuilder
    func body(content: Content) -> some View {
        let shaped = content.contentShape(Rectangle())

        if let onDoubleTap, let onTap {
            shaped
                .onTapGesture(count: 2) { onDoubleTap() }
                .onTapGesture { onTap() }
        } else if let onDoubleTap {
            shaped.onTapGesture(count: 2) { onDoubleTap() }
        } else if let onTap {
            shaped.onTapGesture { onTap() }
        } else {
            shaped
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
    /// The signed-in user's ID — used to highlight which reaction pill is theirs.
    /// `nil` makes the reactions bar read-only.
    var currentUserID: String? = nil
    /// Invoked when the user taps a reaction pill or picks a new emoji.
    /// Pass `nil` to clear. When this is `nil`, the reactions bar is read-only.
    var onReact: ((String?) -> Void)? = nil
    /// Invoked when the user taps the author's avatar or name — callers route
    /// to that user's profile. `nil` leaves the identity row non-interactive
    /// (e.g. on a profile page where the author is already on screen).
    var onAuthorTap: (() -> Void)? = nil
    @Environment(\.colorScheme) var colorScheme

    /// Sourced from `ReviewPagination.cardHeight` so the card and the
    /// carousel that lays it out can never drift apart.
    private var fixedCardHeight: CGFloat { ReviewPagination.cardHeight }
    private let commentLineLimit = 3
    /// The emoji applied by a double-tap "like" gesture. Toggles on/off
    /// (if you already have this emoji as your reaction, double-tap clears it).
    private let likeEmoji = "❤️"

    /// Internally-derived double-tap handler. We don't take it as a parameter
    /// because it's always the same shape (toggle the like emoji), and every
    /// caller already passes `onReact` + `currentUserID`. Nil-out when the
    /// review is your own (can't react to yourself) or when reactions aren't
    /// interactive in this context.
    private var doubleTapToLike: (() -> Void)? {
        guard !isOwnReview,
              let onReact,
              let myID = currentUserID else { return nil }
        return {
            // Subtle haptic so the user knows the double-tap registered even
            // before the heart pill animates in.
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            if review.reaction(by: myID) == likeEmoji {
                onReact(nil)   // toggle off
            } else {
                onReact(likeEmoji) // set (replaces any previous reaction)
            }
        }
    }
    
    /// Avatar + author name (+ "You" badge). Extracted so the same content can
    /// render as a Button label (profile navigation) or as plain content.
    private var authorIdentity: some View {
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
                }
            }
        }
    }

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
                // Avatar + name are one tap target routing to the author's
                // profile (when a handler is provided). The hit area is just
                // the identity content — NOT the flexible gap — so card taps
                // (expand) and double-taps (like) still land everywhere else.
                if let onAuthorTap {
                    Button(action: onAuthorTap) {
                        authorIdentity
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("View \(review.author)'s profile")
                } else {
                    authorIdentity
                }

                Spacer(minLength: 8)

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
            
            // Bottom row: timestamp on the left, friend badge pinned to the right
            // (single-line, fixed-size — the badge never wraps or shrinks).
            HStack(spacing: 8) {
                Text(review.timestamp.formatted(date: .abbreviated, time: .shortened))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .layoutPriority(0)

                Spacer(minLength: 8)

                if isFriend && !isOwnReview {
                    Text("Friend")
                        .font(.caption.bold())
                        .foregroundStyle(.teal)
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.teal.opacity(0.18), in: Capsule())
                        .layoutPriority(1)
                }
            }

            // Reactions bar — pills sorted by count desc, scrolls when too many
            // to fit, with a "+" picker button on the trailing edge when the
            // user is logged in. Always rendered so card height stays fixed.
            //
            // On your *own* reviews the bar is read-only: you can see reactions
            // others left for you, but you don't get the picker or pill-toggle.
            // (Reacting to your own review is both bad UX and would be blocked
            // by Firestore rules anyway — the optimistic update would just
            // flicker and revert.)
            ReactionsBar(
                reactions: review.reactions,
                currentUserID: currentUserID,
                onReact: isOwnReview ? nil : onReact
            )
        }
        .padding(.horizontal, 16)
        .padding(.top, 14)
        .padding(.bottom, 14)
        .frame(height: fixedCardHeight, alignment: .top)
        .background(backgroundShape)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .frame(maxWidth: .infinity, alignment: .leading)
        .modifier(ConditionalTapGestureModifier(onTap: onTap, onDoubleTap: doubleTapToLike))
        // Long-press → Report / Block, for moderating others' content
        // (App Store Guideline 1.2). Only on other people's reviews.
        .modifier(ReviewModerationMenuModifier(enabled: canModerate, review: review))
    }

    /// Report/Block is offered only on other users' reviews when signed in, and
    /// only when we know who wrote it (legacy reviews without an authorID can't
    /// be attributed to a blockable account).
    private var canModerate: Bool {
        currentUserID != nil && !isOwnReview && review.authorID != nil
    }
}

/// Shown in place of a blocked author's review, wherever a review would
/// otherwise appear (App Store Guideline 1.2). The real card is rendered
/// blurred — so both the username and the review text are unreadable, in case
/// the username itself is what got the user blocked — under a generic notice
/// (no name shown) with an inline Unblock affordance.
struct BlockedReviewCard: View {
    let review: Review
    @Environment(NebRatingsStore.self) private var store

    var body: some View {
        ZStack {
            ReviewCard(review: review, showCategory: review.showCategory)
                .blur(radius: 14)
                .allowsHitTesting(false)
                .accessibilityHidden(true)

            VStack(spacing: 8) {
                Image(systemName: "hand.raised.fill")
                    .font(.title2)
                    .foregroundStyle(.secondary)
                Text("You blocked this user")
                    .font(.subheadline.bold())
                    .multilineTextAlignment(.center)
                Text("Their review is hidden.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Button("Unblock") {
                    if let authorID = review.authorID { store.unblockUser(userID: authorID) }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .tint(.purple)
            }
            .padding()
        }
        .frame(height: ReviewPagination.cardHeight)
        .frame(maxWidth: .infinity)
        .background(Color.secondary.opacity(0.06), in: RoundedRectangle(cornerRadius: 16))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

/// Attaches the report/block context menu when `enabled`. Reads the store from
/// the environment lazily (only inside the tap actions) so review-card previews
/// without a store injected never touch it.
private struct ReviewModerationMenuModifier: ViewModifier {
    let enabled: Bool
    let review: Review
    @Environment(NebRatingsStore.self) private var store

    func body(content: Content) -> some View {
        if enabled {
            content.contextMenu {
                Button(role: .destructive) {
                    store.reportReview(review)
                } label: {
                    Label("Report Review", systemImage: "flag")
                }
                if let authorID = review.authorID {
                    Button(role: .destructive) {
                        store.blockUser(userID: authorID, username: review.author)
                    } label: {
                        Label("Block \(review.author)", systemImage: "hand.raised")
                    }
                }
            }
        } else {
            content
        }
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

// MARK: - Edge case: a packed reactions row

/// Many distinct reactors → a long, scrollable strip of varied pills. Exercises
/// the worst case for the reactions bar: mixed single- and multi-count pills,
/// one "mine" (purple) pill, horizontal overflow past the visible width, and
/// the picker button still pinned on the trailing edge. Use this to eyeball
/// pill sizing, the count badges, and that nothing clips top/bottom.
private func packedReactionsReview() -> Review {
    Review(
        showID: 1422,
        showTitle: "Severance",
        showCategory: .series,
        author: "innie_mark",
        comment: "The cold open alone is worth the whole season. Every frame is composed like a painting — and that finale had the whole office screaming.",
        nebRating: 4.5,
        timestamp: Date(),
        // userID → emoji. Repeats build higher counts (❤️ ×3, 😂 ×2, 🔥 ×2)
        // while the rest are singles, so the row mixes 1- and 2-digit badges.
        reactions: [
            "u1": "❤️", "u2": "❤️", "u3": "❤️",
            "u4": "😂", "u5": "😂",
            "u6": "🔥", "u7": "🔥",
            "u8": "👀",
            "u9": "😍",
            "u10": "🤯",
            "u11": "👏",
            "u12": "💯",
            "u13": "🎉",
            "u14": "😭",
            "u15": "🙌",
            "u16": "🤔"
        ]
    )
}

#Preview("Packed Reactions - Light") {
    ReviewCard(
        review: packedReactionsReview(),
        showTitle: "Severance",
        showCategory: .series,
        // Mark this viewer as one of the reactors so a single pill (🔥) renders
        // in the highlighted "mine" purple state alongside the neutral ones.
        currentUserID: "u6",
        onReact: { _ in }
    )
    .padding()
    .background(Color(.systemGroupedBackground))
    .preferredColorScheme(.light)
}

#Preview("Packed Reactions - Dark") {
    ReviewCard(
        review: packedReactionsReview(),
        showTitle: "Severance",
        showCategory: .series,
        currentUserID: "u6",
        onReact: { _ in }
    )
    .padding()
    .background(Color(.systemGroupedBackground))
    .preferredColorScheme(.dark)
}

