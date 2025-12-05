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
            print("🔍 Querying reviews for showID: \(showID)")
            firestoreQuery = firestoreQuery.whereField("showID", isEqualTo: showID)
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
        print("📊 Found \(snapshot.documents.count) review documents in Firestore")
        
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
                    print("⚠️ Review \(document.documentID) has string showID but no tmdbID, skipping")
                    continue
                }
            } else {
                print("Warning: Skipping review document \(document.documentID) - missing showID")
                continue
            }
            
            guard let showTitle = data["showTitle"] as? String,
                  let author = data["author"] as? String,
                  let comment = data["comment"] as? String,
                  let nebRating = data["nebRating"] as? Double else {
                print("Warning: Skipping review document \(document.documentID) - missing required fields")
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
                print("⚠️ Review \(document.documentID) missing category, defaulting to movie")
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
                showCategory: showCategory,
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
        print("💾 Saving review with showID: \(review.showID)")
        let reviewData: [String: Any] = [
            "showID": review.showID,
            "showTitle": review.showTitle,
            "showCategory": review.showCategory.rawValue,
            "author": review.author,
            "comment": review.comment,
            "nebRating": review.nebRating,
            "timestamp": Timestamp(date: review.timestamp),
            "userId": userID  // Keep userId for querying by author
        ]
        
        // Use review.id as the document ID to ensure uniqueness
        try await db.collection("review").document(review.id.uuidString).setData(reviewData)
        print("✅ Review saved successfully")
    }
}

