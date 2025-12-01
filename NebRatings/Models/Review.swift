//
//  Review.swift
//  NebRatings
//
//  Created by Cole Whaley on 11/29/25.
//

import Foundation

struct Review: Identifiable, Hashable {
    let id: UUID
    let showID: UUID
    let showTitle: String
    let author: String
    let comment: String
    let nebRating: Double
    let timestamp: Date

    init(id: UUID = UUID(),
         showID: UUID,
         showTitle: String,
         author: String,
         comment: String,
         nebRating: Double,
         timestamp: Date = .now) {
        self.id = id
        self.showID = showID
        self.showTitle = showTitle
        self.author = author
        self.comment = comment
        self.nebRating = nebRating
        self.timestamp = timestamp
    }
}



