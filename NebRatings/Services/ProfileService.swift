//
//  ProfileService.swift
//  NebRatings
//
//  Created by Cole Whaley on 11/29/25.
//

import Foundation
import FirebaseFirestore
import FirebaseAuth
import FirebaseCore

protocol ProfileService {
    func createProfile(userID: String, name: String) async throws
    func fetchCurrentUser() async throws -> UserProfile
    func fetchReviews(for userID: String) async throws -> [Review]
}

struct FirebaseProfileService: ProfileService {
    private var db: Firestore {
        guard FirebaseApp.app() != nil else {
            fatalError("Firebase is not initialized. Make sure FirebaseApp.configure() is called.")
        }
        return Firestore.firestore()
    }
    
    func createProfile(userID: String, name: String) async throws {
        let profileData: [String: Any] = [
            "name": name
        ]
        
        try await db.collection("profile").document(userID).setData(profileData)
    }
    
    func fetchCurrentUser() async throws -> UserProfile {
        guard let userID = Auth.auth().currentUser?.uid else {
            throw NSError(domain: "ProfileService", code: -1, userInfo: [NSLocalizedDescriptionKey: "No authenticated user"])
        }
        
        let document = try await db.collection("profile").document(userID).getDocument()
        
        guard document.exists,
              let data = document.data(),
              let name = data["name"] as? String else {
            throw NSError(domain: "ProfileService", code: -2, userInfo: [NSLocalizedDescriptionKey: "Profile not found"])
        }
        return UserProfile(id: userID, name: name)
    }

    func fetchReviews(for userID: String) async throws -> [Review] {
        // Query Firestore for user-specific reviews
        let query = db.collection("review")
            .whereField("userId", isEqualTo: userID)
            .limit(to: 100)
        
        let snapshot = try await query.getDocuments()
        
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
        
        return reviews
    }
}





