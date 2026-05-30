//
//  Review.swift
//  NebRatings
//
//  Created by Cole Whaley on 11/29/25.
//

import Foundation

struct Review: Identifiable, Hashable {
    let id: UUID
    let showID: Int  // Use TMDB ID directly
    let showTitle: String
    let showCategory: Show.Category
    let author: String
    let authorID: String?  // Firestore userId of the author — used for avatar/friend resolution
    let comment: String
    let nebRating: Double
    let timestamp: Date
    let season: Int?  // Optional season number (nil means review for entire show)

    init(id: UUID = UUID(),
         showID: Int,
         showTitle: String,
         showCategory: Show.Category,
         author: String,
         authorID: String? = nil,
         comment: String,
         nebRating: Double,
         timestamp: Date = .now,
         season: Int? = nil) {
        self.id = id
        self.showID = showID
        self.showTitle = showTitle
        self.showCategory = showCategory
        self.author = author
        self.authorID = authorID
        self.comment = comment
        self.nebRating = nebRating
        self.timestamp = timestamp
        self.season = season
    }
}

extension Review {
    static let sampleData: [Review] = {
        let now = Date()
        let calendar = Calendar.current
        
        return [
            Review(
                showID: 27205,  // Inception
                showTitle: "Inception",
                showCategory: .movie,
                author: "Alex",
                comment: "Mind-bending masterpiece! The layers of reality had me questioning everything. Christopher Nolan at his finest.",
                nebRating: 5.0,
                timestamp: calendar.date(byAdding: .day, value: -2, to: now) ?? now
            ),
            Review(
                showID: 1396,  // Breaking Bad
                showTitle: "Breaking Bad",
                showCategory: .series,
                author: "Sarah",
                comment: "The character development is absolutely incredible. Walter White's transformation is one of the best arcs in television history.",
                nebRating: 5.0,
                timestamp: calendar.date(byAdding: .day, value: -1, to: now) ?? now
            ),
            Review(
                showID: 155,  // The Dark Knight
                showTitle: "The Dark Knight",
                showCategory: .movie,
                author: "Mike",
                comment: "Heath Ledger's Joker is legendary. The tension and pacing are perfect throughout. A true comic book movie masterpiece.",
                nebRating: 5.0,
                timestamp: calendar.date(byAdding: .hour, value: -12, to: now) ?? now
            ),
            Review(
                showID: 1399,  // Game of Thrones
                showTitle: "Game of Thrones",
                showCategory: .series,
                author: "Emma",
                comment: "The first few seasons are incredible, but the later seasons really dropped the ball. Still worth watching for the early greatness.",
                nebRating: 3.5,
                timestamp: calendar.date(byAdding: .hour, value: -6, to: now) ?? now
            ),
            Review(
                showID: 603,  // The Matrix
                showTitle: "The Matrix",
                showCategory: .movie,
                author: "Jordan",
                comment: "Revolutionary when it came out. The visual effects and philosophical themes still hold up today. Red pill or blue pill?",
                nebRating: 4.5,
                timestamp: calendar.date(byAdding: .hour, value: -3, to: now) ?? now
            ),
            Review(
                showID: 27205,  // Inception (another review)
                showTitle: "Inception",
                showCategory: .movie,
                author: "Chris",
                comment: "Confusing at first but gets better with each rewatch. The score by Hans Zimmer is absolutely phenomenal.",
                nebRating: 4.0,
                timestamp: calendar.date(byAdding: .hour, value: -1, to: now) ?? now
            ),
            Review(
                showID: 1396,  // Breaking Bad (another review)
                showTitle: "Breaking Bad",
                showCategory: .series,
                author: "Taylor",
                comment: "Binge-watched the entire series in a week. Couldn't stop watching. The writing and acting are top-notch.",
                nebRating: 5.0,
                timestamp: now
            ),
            Review(
                showID: 999001,  // Nebula Drift (sample show)
                showTitle: "Nebula Drift",
                showCategory: .movie,
                author: "Cole",
                comment: "Incredible visuals and tense pacing. Dropping full nebs on this one.",
                nebRating: 5.0,
                timestamp: calendar.date(byAdding: .day, value: -5, to: now) ?? now
            ),
            Review(
                showID: 999002,  // Galactic Supper Club (sample show)
                showTitle: "Galactic Supper Club",
                showCategory: .series,
                author: "Lando",
                comment: "Episode 3 made me hungry and emotional. The food cinematography is out of this world!",
                nebRating: 4.5,
                timestamp: calendar.date(byAdding: .day, value: -3, to: now) ?? now
            ),
            Review(
                showID: 155,  // The Dark Knight (another review)
                showTitle: "The Dark Knight",
                showCategory: .movie,
                author: "Riley",
                comment: "Good but overrated in my opinion. The action sequences are great but the plot drags in places.",
                nebRating: 3.0,
                timestamp: calendar.date(byAdding: .hour, value: -8, to: now) ?? now
            )
        ]
    }()
}






