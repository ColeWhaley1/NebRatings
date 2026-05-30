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
    var showID: Int?  // Use TMDB ID directly
    var authorID: String?
    var limit: Int = 50
}

protocol ReviewService {
    func queryReviews(_ query: ReviewQuery) async throws -> [Review]
    func submit(review: Review) async throws
    func update(review: Review) async throws
    func delete(review: Review) async throws
    func deleteAllReviewsByUser(userID: String) async throws
}

struct FirebaseReviewService: ReviewService {
    private var db: Firestore {
        // Return Firestore instance - errors will be handled at the call site if Firebase isn't initialized
        // This prevents app crashes and allows graceful error handling
        return Firestore.firestore()
    }
    
    func queryReviews(_ query: ReviewQuery) async throws -> [Review] {
        var firestoreQuery: Query = db.collection("review")
        
        // Filter by showID if provided
        if let showID = query.showID {
            firestoreQuery = firestoreQuery.whereField("showID", isEqualTo: showID)
        }
        
        // Filter by userId if provided (for authorID queries)
        if let authorID = query.authorID {
            // Need to query by userId field in Firestore
            firestoreQuery = firestoreQuery.whereField("userId", isEqualTo: authorID)
        }
        
        // Filter by minimum rating if provided (do this in Firestore)
        if let minRating = query.minimumRating {
            firestoreQuery = firestoreQuery.whereField("nebRating", isGreaterThanOrEqualTo: minRating)
        }
        
        // Filter by category in Firestore if provided and we're NOT filtering by minimumRating
        // (Firestore compound queries with range filters require composite indexes)
        // If we have both category and minimumRating, we'll filter by category client-side instead
        let shouldFilterCategoryInFirestore = query.category != nil && query.minimumRating == nil
        if shouldFilterCategoryInFirestore {
            firestoreQuery = firestoreQuery.whereField("showCategory", isEqualTo: query.category!.rawValue)
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
            // Handle both old format (showID as String/UUID) and new format (showID as Int)
            let showID: Int
            if let showIDInt = data["showID"] as? Int {
                showID = showIDInt
            } else if let showIDString = data["showID"] as? String {
                // Legacy format - try to extract from showTMDBID or default
                if let tmdbID = data["showTMDBID"] as? Int {
                    showID = tmdbID
                } else {
                    continue
                }
            } else {
                continue
            }
            
            guard let showTitle = data["showTitle"] as? String,
                  let author = data["author"] as? String,
                  let comment = data["comment"] as? String,
                  let nebRating = data["nebRating"] as? Double else {
                continue
            }
            
            // Parse category - handle both old reviews (without category) and new reviews (with category)
            let showCategory: Show.Category
            if let categoryString = data["showCategory"] as? String,
               let category = Show.Category(rawValue: categoryString) {
                showCategory = category
            } else {
                // Fallback: default to movie for existing reviews without category
                showCategory = .movie
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
            
            // Parse season (optional field)
            let season: Int? = data["season"] as? Int

            // Parse author's userId (used for avatar / friend resolution)
            let authorID = data["userId"] as? String

            // Create Review model matching the struct exactly
            let review = Review(
                id: id,
                showID: showID,
                showTitle: showTitle,
                showCategory: showCategory,
                author: author,
                authorID: authorID,
                comment: comment,
                nebRating: nebRating,
                timestamp: timestamp,
                season: season
            )
            
            reviews.append(review)
        }
        
        // Apply category filter client-side if we have both category and minimumRating
        // (to avoid Firestore compound query issues that require composite indexes)
        if let category = query.category, !shouldFilterCategoryInFirestore {
            reviews = reviews.filter { $0.showCategory == category }
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
        var reviewData: [String: Any] = [
            "showID": review.showID,
            "showTitle": review.showTitle,
            "showCategory": review.showCategory.rawValue,
            "author": review.author,
            "comment": review.comment,
            "nebRating": review.nebRating,
            "timestamp": Timestamp(date: review.timestamp),
            "userId": userID  // Keep userId for querying by author
        ]
        
        // Add season if it exists
        if let season = review.season {
            reviewData["season"] = season
        }
        
        // Use review.id as the document ID to ensure uniqueness
        try await db.collection("review").document(review.id.uuidString).setData(reviewData)
    }
    
    func update(review: Review) async throws {
        guard FirebaseApp.app() != nil else {
            throw NSError(domain: "FirebaseReviewService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Firebase is not initialized"])
        }
        
        guard let userID = Auth.auth().currentUser?.uid else {
            throw NSError(domain: "FirebaseReviewService", code: -2, userInfo: [NSLocalizedDescriptionKey: "No authenticated user"])
        }
        
        // Map Review model to Firestore data structure - matching Review struct exactly
        var reviewData: [String: Any] = [
            "showID": review.showID,
            "showTitle": review.showTitle,
            "showCategory": review.showCategory.rawValue,
            "author": review.author,
            "comment": review.comment,
            "nebRating": review.nebRating,
            "timestamp": Timestamp(date: review.timestamp),
            "userId": userID  // Keep userId for querying by author
        ]
        
        // Add season if it exists
        if let season = review.season {
            reviewData["season"] = season
        }
        
        // Update the existing document
        // Note: If season is nil, we don't include it in the update, preserving existing value or leaving it absent
        try await db.collection("review").document(review.id.uuidString).updateData(reviewData)
    }
    
    func delete(review: Review) async throws {
        guard FirebaseApp.app() != nil else {
            throw NSError(domain: "FirebaseReviewService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Firebase is not initialized"])
        }
        
        guard let userID = Auth.auth().currentUser?.uid else {
            throw NSError(domain: "FirebaseReviewService", code: -2, userInfo: [NSLocalizedDescriptionKey: "No authenticated user"])
        }
        
        // Use review.id.uuidString as the document ID (this is how we store it)
        let documentRef = db.collection("review").document(review.id.uuidString)
        
        
        // Let Firestore security rules handle authorization
        // The security rules should check that request.auth.uid == resource.data.userId
        do {
            try await documentRef.delete()
        } catch {
            // Re-throw with more context
            if let nsError = error as NSError? {
            }
            throw error
        }
    }
    
    func deleteAllReviewsByUser(userID: String) async throws {
        guard FirebaseApp.app() != nil else {
            throw NSError(domain: "FirebaseReviewService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Firebase is not initialized"])
        }
        
        // Query all reviews by this user
        let query = db.collection("review")
            .whereField("userId", isEqualTo: userID)
        
        let snapshot = try await query.getDocuments()
        
        // Delete all reviews in batches
        let batch = db.batch()
        var batchCount = 0
        let maxBatchSize = 500 // Firestore batch limit
        
        for document in snapshot.documents {
            batch.deleteDocument(document.reference)
            batchCount += 1
            
            // Commit batch if we reach the limit
            if batchCount >= maxBatchSize {
                try await batch.commit()
                batchCount = 0
            }
        }
        
        // Commit any remaining deletions
        if batchCount > 0 {
            try await batch.commit()
        }
    }
}

