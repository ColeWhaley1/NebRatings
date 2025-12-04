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
        // TODO: Query Firestore for user-specific reviews.
        return Show.sampleData
            .flatMap { $0.reviews }
            .filter { _ in true } // keep all sample reviews
    }
}





