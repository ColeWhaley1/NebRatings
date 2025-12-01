//
//  FirebaseReviewService.swift
//  NebRatings
//
//  Created by Cole Whaley on 11/29/25.
//

import Foundation

struct ReviewQuery {
    var searchText: String?
    var category: Show.Category?
    var minimumRating: Double?
    var showID: UUID?
    var authorID: String?
    var limit: Int = 50
}

protocol ReviewService {
    func queryReviews(_ query: ReviewQuery) async throws -> [Review]
    func submit(review: Review) async throws
}

struct FirebaseReviewService: ReviewService {
    func queryReviews(_ query: ReviewQuery) async throws -> [Review] {
        // TODO: Implement Firebase Firestore query
        // Example structure:
        // var firestoreQuery = Firestore.firestore().collection("reviews")
        // if let showID = query.showID {
        //     firestoreQuery = firestoreQuery.whereField("showID", isEqualTo: showID)
        // }
        // if let category = query.category {
        //     firestoreQuery = firestoreQuery.whereField("category", isEqualTo: category.rawValue)
        // }
        // if let minRating = query.minimumRating {
        //     firestoreQuery = firestoreQuery.whereField("nebRating", isGreaterThanOrEqualTo: minRating)
        // }
        // if let authorID = query.authorID {
        //     firestoreQuery = firestoreQuery.whereField("authorID", isEqualTo: authorID)
        // }
        // let snapshot = try await firestoreQuery.limit(to: query.limit).getDocuments()
        // return snapshot.documents.compactMap { try? $0.data(as: Review.self) }
        
        // For now, return filtered sample data
        var reviews = Show.sampleData.flatMap { $0.reviews }
        
        if let showID = query.showID {
            reviews = reviews.filter { $0.showID == showID }
        }
        
        if let category = query.category {
            // Would need to join with shows to filter by category
            // For now, just return all
        }
        
        if let minRating = query.minimumRating {
            reviews = reviews.filter { $0.nebRating >= minRating }
        }
        
        if let searchText = query.searchText, !searchText.isEmpty {
            let lowered = searchText.lowercased()
            reviews = reviews.filter {
                $0.comment.lowercased().contains(lowered) ||
                $0.author.lowercased().contains(lowered) ||
                $0.showTitle.lowercased().contains(lowered)
            }
        }
        
        return Array(reviews.prefix(query.limit))
    }

    func submit(review: Review) async throws {
        // TODO: Push review to Firebase Firestore
        // Example:
        // let db = Firestore.firestore()
        // try await db.collection("reviews").document(review.id.uuidString).setData(from: review)
    }
}

