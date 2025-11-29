//
//  ProfileService.swift
//  NebRatings
//
//  Created by Cole Whaley on 11/29/25.
//

import Foundation

protocol ProfileService {
    func fetchCurrentUser() async throws -> UserProfile
    func fetchReviews(for userID: String) async throws -> [Review]
}

struct FirebaseProfileService: ProfileService {
    func fetchCurrentUser() async throws -> UserProfile {
        // TODO: Replace with Firebase Auth / Firestore fetch.
        return .sample
    }

    func fetchReviews(for userID: String) async throws -> [Review] {
        // TODO: Query Firestore for user-specific reviews.
        return Show.sampleData
            .flatMap { $0.reviews }
            .filter { _ in true } // keep all sample reviews
    }
}

