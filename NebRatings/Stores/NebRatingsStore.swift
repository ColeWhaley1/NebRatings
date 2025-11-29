//
//  NebRatingsStore.swift
//  NebRatings
//
//  Created by Cole Whaley on 11/29/25.
//

import Foundation

@MainActor
@Observable
final class NebRatingsStore {
    private(set) var shows: [Show]
    private(set) var reviews: [Review]
    private(set) var currentUser: UserProfile?
    private(set) var userReviews: [Review]

    private let catalogService: CatalogService
    private let reviewService: ReviewService
    private let profileService: ProfileService

    init(catalogService: CatalogService = TMDBService(),
         reviewService: ReviewService = FirebaseReviewService(),
         profileService: ProfileService = FirebaseProfileService()) {
        self.catalogService = catalogService
        self.reviewService = reviewService
        self.profileService = profileService

        let seededShows = Show.sampleData
        self.shows = seededShows
        self.reviews = seededShows.flatMap { $0.reviews }
        self.currentUser = nil
        self.userReviews = []

        Task {
            await bootstrap()
        }
    }

    func bootstrap() async {
        await loadShows()
        await loadReviews()
        await loadUserProfile()
    }

    func loadShows() async {
        do {
            let remoteShows = try await catalogService.fetchShows()
            await MainActor.run {
                self.shows = remoteShows
            }
        } catch {
            // Keep local sample data for now.
        }
    }

    func loadReviews() async {
        do {
            let remoteReviews = try await reviewService.fetchReviews()
            await MainActor.run {
                self.reviews = remoteReviews
            }
        } catch {
            // Keep local sample data for now.
        }
    }

    func loadUserProfile() async {
        do {
            let profile = try await profileService.fetchCurrentUser()
            await MainActor.run {
                self.currentUser = profile
            }
            await loadUserReviews(for: profile.id)
        } catch {
            // Ignore for now and keep placeholder user nil.
        }
    }

    private func loadUserReviews(for userID: String) async {
        do {
            let reviews = try await profileService.fetchReviews(for: userID)
            await MainActor.run {
                self.userReviews = reviews
            }
        } catch {
            // Keep existing user reviews.
        }
    }

    func reviews(for show: Show) -> [Review] {
        reviews.filter { $0.showID == show.id }
    }

    func show(for review: Review) -> Show? {
        shows.first(where: { $0.id == review.showID })
    }

    func addReview(author: String, comment: String, rating: Double, to show: Show) {
        var newReview = Review(showID: show.id, showTitle: show.title, author: author, comment: comment, nebRating: rating)
        reviews.insert(newReview, at: 0)

        if let index = shows.firstIndex(where: { $0.id == show.id }) {
            shows[index].reviews.insert(newReview, at: 0)
        }

        Task {
            try? await reviewService.submit(review: newReview)
        }
    }
}

