//
//  Show.swift
//  NebRatings
//
//  Created by Cole Whaley on 11/29/25.
//

import Foundation
import SwiftUI

struct WatchProviderInfo: Identifiable, Hashable {
    let id: Int
    let name: String
    let logoURL: String?
}

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

    let id: Int  // Use TMDB ID directly as the identifier
    let title: String
    let category: Category
    let year: Int
    let synopsis: String
    let tagline: String
    let streamingService: String
    let posterURL: String?
    let backdropURL: String?
    let popularity: Double
    let genres: [String]
    let rating: Double?
    let watchProviders: [WatchProviderInfo]
    var reviews: [Review]

    init(id: Int,
         title: String,
         category: Category,
         year: Int,
         synopsis: String,
         tagline: String,
         streamingService: String,
         posterURL: String? = nil,
         backdropURL: String? = nil,
         popularity: Double = 0.0,
         genres: [String] = [],
         rating: Double? = nil,
         watchProviders: [WatchProviderInfo] = [],
         reviews: [Review] = []) {
        self.id = id
        self.title = title
        self.category = category
        self.year = year
        self.synopsis = synopsis
        self.tagline = tagline
        self.streamingService = streamingService
        self.posterURL = posterURL
        self.backdropURL = backdropURL
        self.popularity = popularity
        self.genres = genres
        self.rating = rating
        self.watchProviders = watchProviders
        self.reviews = reviews
    }
    
    // Computed property for backward compatibility if needed
    var tmdbID: Int? {
        return id
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
            id: 999001,  // Placeholder ID for sample data
            title: "Nebula Drift",
            category: .movie,
            year: 2025,
            synopsis: "A rogue pilot must steer a lost colony ship through a chaotic nebula to get her crew home.",
            tagline: "Hold your breath. Count the nebs.",
            streamingService: "Neb+"
        )
        nebulaDrift.reviews = [
            Review(showID: nebulaDrift.id, showTitle: nebulaDrift.title, showCategory: nebulaDrift.category, author: "Cole", comment: "Incredible visuals and tense pacing. Dropping full nebs on this one.", nebRating: 5),
            Review(showID: nebulaDrift.id, showTitle: nebulaDrift.title, showCategory: nebulaDrift.category, author: "Mara", comment: "A bit cliché but the final act sticks the landing.", nebRating: 3.5)
        ]

        var supperClub = Show(
            id: 999002,  // Placeholder ID for sample data
            title: "Galactic Supper Club",
            category: .series,
            year: 2024,
            synopsis: "A chef travels planet-to-planet hosting pop-up dinners with alien ingredients.",
            tagline: "Food critics now measure flavor in nebs.",
            streamingService: "StreamSphere"
        )
        supperClub.reviews = [
            Review(showID: supperClub.id, showTitle: supperClub.title, showCategory: supperClub.category, author: "Lando", comment: "Episode 3 made me hungry and emotional.", nebRating: 4.5)
        ]

        let echoes = Show(
            id: 999003,  // Placeholder ID for sample data
            title: "Chronicle of Echoes",
            category: .series,
            year: 2023,
            synopsis: "Detectives decode memories left behind in sound waves to solve cold cases.",
            tagline: "Every echo earns a neb.",
            streamingService: "PulseTV"
        )

        return [nebulaDrift, supperClub, echoes]
    }()
    
    // Preview data that resembles TMDB API responses
    static let previewData: [Show] = {
        let inception = Show(
            id: 27205,  // Use TMDB ID directly
            title: "Inception",
            category: .movie,
            year: 2010,
            synopsis: "Cobb, a skilled thief who commits corporate espionage by infiltrating the subconscious of his targets is offered a chance to regain his old life as payment for a task considered to be impossible: \"inception\", the implantation of another person's idea into a target's subconscious.",
            tagline: "Your mind is the scene of the crime.",
            streamingService: "Netflix",
            posterURL: "https://image.tmdb.org/t/p/w500/oYuLEt3zVCKq57qu2F8dT7NIa6f.jpg",
            backdropURL: "https://image.tmdb.org/t/p/w780/s3TBrRGB1iav7gFOCNx3H31MoES.jpg",
            popularity: 24.631,
            genres: ["Action", "Sci-Fi", "Thriller"],
            rating: 8.8,
            watchProviders: [
                WatchProviderInfo(id: 8, name: "Netflix", logoURL: "https://image.tmdb.org/t/p/w45/t2yyOv40HZeVlLjYsCsPHnWLk4W.jpg"),
                WatchProviderInfo(id: 384, name: "HBO Max", logoURL: "https://image.tmdb.org/t/p/w45/4KAy34EHvRM25Ih8wb82AuGU7zJ.jpg")
            ]
        )
        
        let breakingBad = Show(
            id: 1396,  // Use TMDB ID directly
            title: "Breaking Bad",
            category: .series,
            year: 2008,
            synopsis: "When Walter White, a New Mexico chemistry teacher, is diagnosed with Stage III cancer and given a prognosis of only two years left to live, he becomes filled with a sense of fearlessness and an unrelenting desire to secure his family's financial future at any cost as he enters the dangerous world of drugs and crime.",
            tagline: "All bad things must come to an end.",
            streamingService: "Netflix",
            posterURL: "https://image.tmdb.org/t/p/w500/ggFHVNu6YYI5L9pCfOacjizRGt.jpg",
            backdropURL: "https://image.tmdb.org/t/p/w780/tsRy63Mu5cu8etL1X7ZLyf7UP1M.jpg",
            popularity: 18.234,
            genres: ["Crime", "Drama", "Thriller"],
            rating: 9.5,
            watchProviders: [
                WatchProviderInfo(id: 8, name: "Netflix", logoURL: "https://image.tmdb.org/t/p/w45/t2yyOv40HZeVlLjYsCsPHnWLk4W.jpg"),
                WatchProviderInfo(id: 528, name: "AMC+", logoURL: "https://image.tmdb.org/t/p/w45/4KAy34EHvRM25Ih8wb82AuGU7zJ.jpg")
            ]
        )
        
        let theDarkKnight = Show(
            id: 155,  // Use TMDB ID directly
            title: "The Dark Knight",
            category: .movie,
            year: 2008,
            synopsis: "Batman raises the stakes in his war on crime. With the help of Lt. Jim Gordon and District Attorney Harvey Dent, Batman sets out to dismantle the remaining criminal organizations that plague the streets. The partnership proves to be effective, but they soon find themselves prey to a reign of chaos unleashed by a rising criminal mastermind known to the terrified citizens of Gotham as the Joker.",
            tagline: "Why So Serious?",
            streamingService: "HBO Max",
            posterURL: "https://image.tmdb.org/t/p/w500/qJ2tW6WMUDux911r6m7haRef0WH.jpg",
            backdropURL: "https://image.tmdb.org/t/p/w780/hqkIcbrOHL86UncnHIsHVcVmzue.jpg",
            popularity: 22.456,
            genres: ["Action", "Crime", "Drama"],
            rating: 9.0,
            watchProviders: [
                WatchProviderInfo(id: 384, name: "HBO Max", logoURL: "https://image.tmdb.org/t/p/w45/4KAy34EHvRM25Ih8wb82AuGU7zJ.jpg")
            ]
        )
        
        let gameOfThrones = Show(
            id: 1399,  // Use TMDB ID directly
            title: "Game of Thrones",
            category: .series,
            year: 2011,
            synopsis: "Seven noble families fight for control of the mythical land of Westeros. Friction between the houses leads to full-scale war. All while a very ancient evil awakens in the farthest north. Amidst the war, a neglected military order of misfits, the Night's Watch, is all that stands between the realms of men and icy horrors beyond.",
            tagline: "Winter is Coming.",
            streamingService: "HBO Max",
            posterURL: "https://image.tmdb.org/t/p/w500/u3bZgnGQ9T01sWNhyveQz0wH0Hl.jpg",
            backdropURL: "https://image.tmdb.org/t/p/w780/2OMB0ynKlyIenMJWI2Dy9IWT4cM.jpg",
            popularity: 19.789,
            genres: ["Action", "Adventure", "Drama", "Fantasy"],
            rating: 8.5,
            watchProviders: [
                WatchProviderInfo(id: 384, name: "HBO Max", logoURL: "https://image.tmdb.org/t/p/w45/4KAy34EHvRM25Ih8wb82AuGU7zJ.jpg")
            ]
        )
        
        let noPosterShow = Show(
            id: 603,  // Use TMDB ID directly
            title: "The Matrix",
            category: .movie,
            year: 1999,
            synopsis: "Set in the 22nd century, The Matrix tells the story of a computer hacker who learns from mysterious rebels about the true nature of his reality and his role in the war against its controllers.",
            tagline: "Welcome to the Real World.",
            streamingService: "HBO Max",
            posterURL: nil,
            backdropURL: nil,
            popularity: 15.123,
            genres: ["Action", "Sci-Fi"],
            rating: 8.7,
            watchProviders: [
                WatchProviderInfo(id: 384, name: "HBO Max", logoURL: "https://image.tmdb.org/t/p/w45/4KAy34EHvRM25Ih8wb82AuGU7zJ.jpg")
            ]
        )
        
        return [inception, breakingBad, theDarkKnight, gameOfThrones, noPosterShow]
    }()
}

