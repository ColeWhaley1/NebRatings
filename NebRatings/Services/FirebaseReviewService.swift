//
//  FirebaseReviewService.swift
//  NebRatings
//
//  Created by Cole Whaley on 11/29/25.
//

import Foundation

protocol ReviewService {
    func fetchReviews() async throws -> [Review]
    func submit(review: Review) async throws
}

struct FirebaseReviewService: ReviewService {
    func fetchReviews() async throws -> [Review] {
        // TODO: Swap in Firebase Firestore fetch logic.
        return Show.sampleData.flatMap { $0.reviews }
    }

    func submit(review: Review) async throws {
        // TODO: Push review to Firebase backend.
    }
}

