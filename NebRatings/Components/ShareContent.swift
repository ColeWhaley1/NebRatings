//
//  ShareContent.swift
//  NebRatings
//
//  ShareService — the single place everything shareable turns into
//  iOS share-sheet content. Every share carries an enticing, download-
//  driving line plus a Universal Link to nebratings.com, so a tapped link
//  opens the app (or the web page → App Store when it isn't installed).
//
//  Call sites just do:
//      shareItems = await ShareService.items(for: .show(show, myReview: r))
//      isSharePresented = true
//  and present `ActivityShareSheet(items:)`.
//

import SwiftUI
import UIKit

enum ShareService {

    /// Everything the app can share. Add a case here + a builder below to
    /// give a new surface a link — nothing else needs to change.
    enum Subject {
        case show(Show, myReview: Review?)
        case review(Review, show: Show?)
        case profile(UserProfile)
        case list(ShowList, ownerName: String?)
        case watchTogether(picks: [GroupRecommendation], groupNames: [String])
        case yearInReview(year: Int, card: UIImage, sharerID: String?)
    }

    /// Activity items for `UIActivityViewController`: an enticing text line,
    /// the Universal Link as its own item (so share targets can render a
    /// rich preview / "Copy Link"), and an image where we have one. Async
    /// because show/review shares fetch a poster.
    static func items(for subject: Subject) async -> [Any] {
        switch subject {
        case .show(let show, let myReview):
            return await showItems(show, myReview: myReview)
        case .review(let review, let show):
            return await reviewItems(review, show: show)
        case .profile(let profile):
            return profileItems(profile)
        case .list(let list, let ownerName):
            return listItems(list, ownerName: ownerName)
        case .watchTogether(let picks, let names):
            return watchTogetherItems(picks, groupNames: names)
        case .yearInReview(let year, let card, let sharerID):
            return yearInReviewItems(year: year, card: card, sharerID: sharerID)
        }
    }

    // MARK: - Show

    private static func showItems(_ show: Show, myReview: Review?) async -> [Any] {
        let link = DeepLink.show(id: show.id, category: show.category).shareURL
        var items: [Any] = []

        if let myReview {
            var text = "🔥 I rated \(show.title) \(rating(myReview.nebRating))/10 on NebRatings"
            if let comment = trimmed(myReview.comment) {
                text += "\n“\(comment)”"
            }
            text += "\n\(callToAction("Rate it yourself and see what your friends think 👇"))"
            items.append(text)
        } else {
            let kind = show.category == .movie ? "movie" : "show"
            items.append("🍿 \(show.title) (\(show.year)) — see how friends rated this \(kind) and drop your own nebs on NebRatings 👇")
        }

        if let link { items.append(link) }
        if let poster = await posterImage(from: show.posterURL) { items.append(poster) }
        return items
    }

    // MARK: - Review

    private static func reviewItems(_ review: Review, show: Show?) async -> [Any] {
        let link = DeepLink.show(id: review.showID, category: review.showCategory).shareURL
        var text = "\(review.author) rated \(review.showTitle) \(rating(review.nebRating))/10 on NebRatings 🔥"
        if let comment = trimmed(review.comment) {
            text += "\n“\(comment)”"
        }
        text += "\n\(callToAction("See more reviews and rate your own 👇"))"

        var items: [Any] = [text]
        if let link { items.append(link) }
        if let poster = await posterImage(from: show?.posterURL) { items.append(poster) }
        return items
    }

    // MARK: - Profile

    private static func profileItems(_ profile: UserProfile) -> [Any] {
        let link = DeepLink.profile(userID: profile.id).shareURL
        var text = "🍿 Check out \(profile.username)'s movie & TV taste on NebRatings"
        if let genres = profile.favoriteGenres, !genres.isEmpty {
            text += "\nInto \(genres.prefix(3).joined(separator: ", "))"
        }
        text += "\n\(callToAction("See their ratings, reviews & lists — and how your taste compares 💜"))"

        var items: [Any] = [text]
        if let link { items.append(link) }
        return items
    }

    // MARK: - List

    private static func listItems(_ list: ShowList, ownerName: String?) -> [Any] {
        let link = DeepLink.list(id: list.id).shareURL
        let count = list.showReferences.count
        let owner = ownerName.map { "\($0)'s" } ?? "this"
        var text = "🎬 Check out \(owner) “\(list.name)” list on NebRatings"
        text += " — \(count) \(count == 1 ? "title" : "titles") to watch."
        text += "\n\(callToAction("See the full list and build your own 👇"))"

        var items: [Any] = [text]
        if let link { items.append(link) }
        return items
    }

    // MARK: - Watch Together

    private static func watchTogetherItems(_ picks: [GroupRecommendation], groupNames: [String]) -> [Any] {
        var lines = ["🍿 Our NebRatings picks for movie night:"]
        for pick in picks.prefix(5) {
            lines.append("• \(pick.show.title) — \(pick.confidence)% match")
        }
        let who = groupNames.isEmpty ? "your crew" : groupNames.prefix(2).joined(separator: " & ")
        lines.append(callToAction("Find what \(who) should watch next on NebRatings 👇"))

        var items: [Any] = [lines.joined(separator: "\n")]
        if let link = DeepLinkConfig.homeURL { items.append(link) }
        return items
    }

    // MARK: - Year in Review

    private static func yearInReviewItems(year: Int, card: UIImage, sharerID: String?) -> [Any] {
        // Link to the sharer's profile when we have it (so viewers can
        // follow / compare), otherwise the app home.
        let link = sharerID.flatMap { DeepLink.profile(userID: $0).shareURL } ?? DeepLinkConfig.homeURL
        let text = "My \(year) in movies & TV, wrapped by NebRatings 🎬🔥\n\(callToAction("See yours 👇"))"

        var items: [Any] = [card, text]
        if let link { items.append(link) }
        return items
    }

    // MARK: - Helpers

    /// Fetches a poster as a UIImage for richer shares. nil on any failure.
    static func posterImage(from urlString: String?) async -> UIImage? {
        guard let urlString, let url = URL(string: urlString) else { return nil }
        guard let (data, response) = try? await URLSession.shared.data(from: url),
              let http = response as? HTTPURLResponse,
              (200...299).contains(http.statusCode) else { return nil }
        return UIImage(data: data)
    }

    /// The download nudge. When links are live the URL item does the driving,
    /// so the copy stays about the payoff, not a naked "download" plea.
    private static func callToAction(_ text: String) -> String {
        DeepLinkConfig.isUniversalLinkingEnabled ? text : "\(text)\nnebratings.com"
    }

    private static func trimmed(_ text: String) -> String? {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return t.isEmpty ? nil : t
    }

    /// 7.0 → "7", 7.5 → "7.5".
    private static func rating(_ value: Double) -> String {
        value.truncatingRemainder(dividingBy: 1) == 0
            ? String(format: "%.0f", value)
            : String(format: "%.1f", value)
    }
}

/// UIActivityViewController wrapper — used (instead of ShareLink) because a
/// share bundles heterogeneous items: text, a link, and often an image.
struct ActivityShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}

/// Identifiable wrapper so share sheets are presented with `.sheet(item:)`
/// rather than `.sheet(isPresented:)`. The items are assembled asynchronously
/// (`ShareService.items` awaits link/image work); presenting by a Bool while
/// reading a separate `@State` array races the first tap — the sheet can be
/// built before the items land, showing an empty drawer (just the app icon)
/// until a second tap. Presenting by item builds the sheet only once the
/// payload exists, and always with the correct contents.
struct SharePayload: Identifiable {
    let id = UUID()
    let items: [Any]
}
