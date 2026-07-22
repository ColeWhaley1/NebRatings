//
//  Activity.swift
//  NebRatings
//
//  One social-feed event. Two sources feed the Activity tab:
//    • "rated" events are DERIVED from review documents at read time —
//      reviews stay the single source of truth for ratings, nothing is
//      double-written.
//    • List events (created list / added a title) and review updates are
//      persisted in the `activity` collection when they happen — they have
//      no other queryable record.
//

import Foundation

struct Activity: Identifiable, Hashable {
    enum Kind: String {
        case rated
        case updatedReview
        case createdList
        case addedToList
    }

    let id: String
    let userID: String
    let username: String
    let kind: Kind
    let timestamp: Date

    // Show payload (rated / updatedReview / addedToList)
    let showID: Int?
    let showTitle: String?
    let showCategory: Show.Category?
    let rating: Double?
    let season: Int?

    // List payload (createdList / addedToList)
    let listID: String?
    let listName: String?
    /// Visibility of the list at the time of the event — the feed only
    /// shows friends-only list events to the owner's friends.
    let listVisibility: ListVisibility?

    init(id: String,
         userID: String,
         username: String,
         kind: Kind,
         timestamp: Date,
         showID: Int? = nil,
         showTitle: String? = nil,
         showCategory: Show.Category? = nil,
         rating: Double? = nil,
         season: Int? = nil,
         listID: String? = nil,
         listName: String? = nil,
         listVisibility: ListVisibility? = nil) {
        self.id = id
        self.userID = userID
        self.username = username
        self.kind = kind
        self.timestamp = timestamp
        self.showID = showID
        self.showTitle = showTitle
        self.showCategory = showCategory
        self.rating = rating
        self.season = season
        self.listID = listID
        self.listName = listName
        self.listVisibility = listVisibility
    }

    /// A derived "rated" event from a review document.
    static func rated(from review: Review) -> Activity {
        Activity(
            id: "rated_\(review.id.uuidString)",
            userID: review.authorID ?? "",
            username: review.author,
            kind: .rated,
            timestamp: review.timestamp,
            showID: review.showID,
            showTitle: review.showTitle,
            showCategory: review.showCategory,
            rating: review.nebRating,
            season: review.season
        )
    }
}
