//
//  FirebaseReviewService.swift
//  NebRatings
//
//  Created by Cole Whaley on 11/29/25.
//

import Foundation
import FirebaseFirestore
import FirebaseAuth
import FirebaseCore

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
    private var db: Firestore {
        guard FirebaseApp.app() != nil else {
            fatalError("Firebase is not initialized. Make sure FirebaseApp.configure() is called.")
        }
        return Firestore.firestore()
    }
    
    func queryReviews(_ query: ReviewQuery) async throws -> [Review] {
        var firestoreQuery: Query = db.collection("review")
        
        // Filter by showID if provided
        if let showID = query.showID {
            firestoreQuery = firestoreQuery.whereField("showID", isEqualTo: showID.uuidString)
        }
        
        // Filter by userId if provided (for authorID queries)
        if let authorID = query.authorID {
            // Need to query by userId field in Firestore
            firestoreQuery = firestoreQuery.whereField("userId", isEqualTo: authorID)
        }
        
        // Filter by minimum rating if provided
        if let minRating = query.minimumRating {
            firestoreQuery = firestoreQuery.whereField("nebRating", isGreaterThanOrEqualTo: minRating)
        }
        
        // Apply limit
        firestoreQuery = firestoreQuery.limit(to: query.limit)
        
        // Execute query
        let snapshot = try await firestoreQuery.getDocuments()
        
        // Map Firestore documents to Review models
        var reviews: [Review] = []
        
        for document in snapshot.documents {
            let data = document.data()
            
            // Parse all fields matching Review struct structure
            guard let showIDString = data["showID"] as? String,
                  let showID = UUID(uuidString: showIDString),
                  let showTitle = data["showTitle"] as? String,
                  let author = data["author"] as? String,
                  let comment = data["comment"] as? String,
                  let nebRating = data["nebRating"] as? Double else {
                print("Warning: Skipping review document \(document.documentID) - missing required fields")
                continue
            }
            
            // Parse timestamp
            let timestamp: Date
            if let timestampValue = data["timestamp"] as? Timestamp {
                timestamp = timestampValue.dateValue()
            } else {
                // Fallback to current date if timestamp is missing
                timestamp = Date()
            }
            
            // Parse id from document ID
            let id = UUID(uuidString: document.documentID) ?? UUID()
            
            // Create Review model matching the struct exactly
            let review = Review(
                id: id,
                showID: showID,
                showTitle: showTitle,
                author: author,
                comment: comment,
                nebRating: nebRating,
                timestamp: timestamp
            )
            
            reviews.append(review)
        }
        
        // Apply text search filter if provided (client-side since Firestore text search is limited)
        if let searchText = query.searchText, !searchText.isEmpty {
            let lowered = searchText.lowercased()
            reviews = reviews.filter {
                $0.comment.lowercased().contains(lowered) ||
                $0.author.lowercased().contains(lowered) ||
                $0.showTitle.lowercased().contains(lowered)
            }
        }
        
        return reviews
    }

    func submit(review: Review) async throws {
        guard FirebaseApp.app() != nil else {
            throw NSError(domain: "FirebaseReviewService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Firebase is not initialized"])
        }
        
        guard let userID = Auth.auth().currentUser?.uid else {
            throw NSError(domain: "FirebaseReviewService", code: -2, userInfo: [NSLocalizedDescriptionKey: "No authenticated user"])
        }
        
        // Map Review model to Firestore data structure - matching Review struct exactly
        let reviewData: [String: Any] = [
            "showID": review.showID.uuidString,
            "showTitle": review.showTitle,
            "author": review.author,
            "comment": review.comment,
            "nebRating": review.nebRating,
            "timestamp": Timestamp(date: review.timestamp),
            "userId": userID  // Keep userId for querying by author
        ]
        
        // Use review.id as the document ID to ensure uniqueness
        try await db.collection("review").document(review.id.uuidString).setData(reviewData)
    }
}

