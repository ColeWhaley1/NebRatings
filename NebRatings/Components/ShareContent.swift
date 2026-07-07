//
//  ShareContent.swift
//  NebRatings
//
//  Native share-sheet support for ratings and reviews. Builds polished share
//  text (title, rating, review quote) and bundles the poster image when it
//  can be fetched. Structured so Universal Links can be added later: when a
//  web URL scheme exists, return it from `shareURL(for:)` and it joins the
//  activity items — no call-site changes needed.
//

import SwiftUI
import UIKit

enum ShareContentBuilder {
    /// Share text for a review (mine or someone else's).
    static func text(for review: Review, showYear: Int? = nil) -> String {
        var lines: [String] = []
        let yearSuffix = showYear.map { " (\($0))" } ?? ""
        lines.append("\(review.showTitle)\(yearSuffix)")
        if let season = review.season {
            lines.append("Season \(season)")
        }
        lines.append("🔥 \(formattedRating(review.nebRating))/10 nebs")
        let comment = review.comment.trimmingCharacters(in: .whitespacesAndNewlines)
        if !comment.isEmpty {
            lines.append("“\(comment)”")
        }
        lines.append("— \(review.author) on NebRatings")
        if let url = shareURL(showID: review.showID, category: review.showCategory) {
            lines.append(url.absoluteString)
        }
        return lines.joined(separator: "\n")
    }

    /// Share text for a show/movie, optionally with my rating + review.
    static func text(for show: Show, myReview: Review?) -> String {
        var lines: [String] = []
        lines.append("\(show.title) (\(show.year))")
        if let myReview {
            lines.append("🔥 I rated it \(formattedRating(myReview.nebRating))/10 nebs")
            let comment = myReview.comment.trimmingCharacters(in: .whitespacesAndNewlines)
            if !comment.isEmpty {
                lines.append("“\(comment)”")
            }
        }
        lines.append("Shared from NebRatings")
        if let url = shareURL(showID: show.id, category: show.category) {
            lines.append(url.absoluteString)
        }
        return lines.joined(separator: "\n")
    }

    /// Future Universal Links hook. Returns nil until a web domain exists;
    /// when it does, produce e.g. https://nebratings.app/show/{category}/{id}
    /// here and every share automatically carries a deep link.
    static func shareURL(showID: Int, category: Show.Category) -> URL? {
        nil
    }

    /// Fetches the poster as a UIImage for richer shares. Returns nil on any
    /// failure — callers share text-only in that case.
    static func posterImage(from urlString: String?) async -> UIImage? {
        guard let urlString, let url = URL(string: urlString) else { return nil }
        guard let (data, response) = try? await URLSession.shared.data(from: url),
              let http = response as? HTTPURLResponse,
              (200...299).contains(http.statusCode) else { return nil }
        return UIImage(data: data)
    }

    /// 7.0 → "7", 7.5 → "7.5" — matches how ratings read in the app.
    private static func formattedRating(_ rating: Double) -> String {
        rating.truncatingRemainder(dividingBy: 1) == 0
            ? String(format: "%.0f", rating)
            : String(format: "%.1f", rating)
    }
}

/// UIActivityViewController wrapper — used (instead of ShareLink) because a
/// share can bundle heterogeneous items: text plus an optional poster image.
struct ActivityShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
