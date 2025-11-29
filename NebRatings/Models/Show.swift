//
//  Show.swift
//  NebRatings
//
//  Created by Cole Whaley on 11/29/25.
//

import Foundation
import SwiftUI

struct Show: Identifiable, Hashable {
    enum Category: String, CaseIterable, Identifiable {
        case movie = "Movie"
        case series = "Series"

        var id: String { rawValue }

        var badgeColor: Color {
            switch self {
            case .movie: return .orange
            case .series: return .blue
            }
        }
    }

    let id: UUID
    let title: String
    let category: Category
    let year: Int
    let synopsis: String
    let tagline: String
    let streamingService: String
    var reviews: [Review]

    init(id: UUID = UUID(),
         title: String,
         category: Category,
         year: Int,
         synopsis: String,
         tagline: String,
         streamingService: String,
         reviews: [Review] = []) {
        self.id = id
        self.title = title
        self.category = category
        self.year = year
        self.synopsis = synopsis
        self.tagline = tagline
        self.streamingService = streamingService
        self.reviews = reviews
    }

    var averageNebs: Double {
        guard !reviews.isEmpty else { return 0 }
        let total = reviews.reduce(0) { $0 + $1.nebRating }
        return total / Double(reviews.count)
    }

    func matches(_ term: String) -> Bool {
        let lowered = term.lowercased()
        return title.lowercased().contains(lowered)
        || synopsis.lowercased().contains(lowered)
        || tagline.lowercased().contains(lowered)
        || streamingService.lowercased().contains(lowered)
    }
}

extension Show {
    static let sampleData: [Show] = {
        var nebulaDrift = Show(
            title: "Nebula Drift",
            category: .movie,
            year: 2025,
            synopsis: "A rogue pilot must steer a lost colony ship through a chaotic nebula to get her crew home.",
            tagline: "Hold your breath. Count the nebs.",
            streamingService: "Neb+"
        )
        nebulaDrift.reviews = [
            Review(showID: nebulaDrift.id, showTitle: nebulaDrift.title, author: "Cole", comment: "Incredible visuals and tense pacing. Dropping full nebs on this one.", nebRating: 5),
            Review(showID: nebulaDrift.id, showTitle: nebulaDrift.title, author: "Mara", comment: "A bit cliché but the final act sticks the landing.", nebRating: 3.5)
        ]

        var supperClub = Show(
            title: "Galactic Supper Club",
            category: .series,
            year: 2024,
            synopsis: "A chef travels planet-to-planet hosting pop-up dinners with alien ingredients.",
            tagline: "Food critics now measure flavor in nebs.",
            streamingService: "StreamSphere"
        )
        supperClub.reviews = [
            Review(showID: supperClub.id, showTitle: supperClub.title, author: "Lando", comment: "Episode 3 made me hungry and emotional.", nebRating: 4.5)
        ]

        let echoes = Show(
            title: "Chronicle of Echoes",
            category: .series,
            year: 2023,
            synopsis: "Detectives decode memories left behind in sound waves to solve cold cases.",
            tagline: "Every echo earns a neb.",
            streamingService: "PulseTV"
        )

        return [nebulaDrift, supperClub, echoes]
    }()
}

