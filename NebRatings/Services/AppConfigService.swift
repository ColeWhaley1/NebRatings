//
//  AppConfigService.swift
//  NebRatings
//
//  Remote app configuration via Firestore. Currently one document:
//  appConfig/seasonalCollections — an owner-curated replacement for the
//  built-in seasonal catalog, so Discover's seasonal rows can be re-curated
//  server-side without shipping an app update. Missing document or parse
//  failure → nil → the app falls back to SeasonalCatalog.builtIn.
//
//  Document shape:
//    {
//      "collections": [
//        {
//          "id": "christmas-movies",
//          "title": "Christmas Movies",
//          "emoji": "🎄",
//          "subtitle": "Tis the season",         // optional
//          "startMonth": 12, "startDay": 1,
//          "endMonth": 12, "endDay": 26,
//          "movieGenreIDs": [35],                // optional
//          "tvGenreIDs": [],                     // optional
//          "keywords": ["christmas"],            // optional
//          "includeMovies": true,                // optional (default true)
//          "includeTV": false,                   // optional (default false)
//          "minVoteAverage": 6.0,                // optional
//          "minVoteCount": 100,                  // optional
//          "sortBy": "popularity.desc"           // optional
//        }, …
//      ]
//    }
//

import Foundation
import FirebaseFirestore

protocol AppConfigService {
    /// Remote seasonal catalog, or nil when unset/unreachable (use built-in).
    func fetchSeasonalCollections() async throws -> [SeasonalCollection]?
}

struct FirebaseAppConfigService: AppConfigService {
    private var db: Firestore { Firestore.firestore() }

    func fetchSeasonalCollections() async throws -> [SeasonalCollection]? {
        let document = try await db.collection("appConfig").document("seasonalCollections").getDocument()
        guard document.exists,
              let data = document.data(),
              let rawCollections = data["collections"] as? [[String: Any]] else {
            return nil
        }

        let parsed = rawCollections.compactMap(parseCollection)
        // An empty remote list is treated as "not configured" rather than
        // "hide everything" — deleting entries shouldn't brick the section.
        return parsed.isEmpty ? nil : parsed
    }

    private func parseCollection(_ raw: [String: Any]) -> SeasonalCollection? {
        guard let id = raw["id"] as? String,
              let title = raw["title"] as? String,
              let startMonth = intValue(raw["startMonth"]),
              let startDay = intValue(raw["startDay"]),
              let endMonth = intValue(raw["endMonth"]),
              let endDay = intValue(raw["endDay"])
        else { return nil }

        return SeasonalCollection(
            id: id,
            title: title,
            emoji: raw["emoji"] as? String ?? "✨",
            subtitle: raw["subtitle"] as? String,
            startMonth: startMonth, startDay: startDay,
            endMonth: endMonth, endDay: endDay,
            movieGenreIDs: intArray(raw["movieGenreIDs"]),
            tvGenreIDs: intArray(raw["tvGenreIDs"]),
            keywords: raw["keywords"] as? [String] ?? [],
            includeMovies: raw["includeMovies"] as? Bool ?? true,
            includeTV: raw["includeTV"] as? Bool ?? false,
            minVoteAverage: doubleValue(raw["minVoteAverage"]),
            minVoteCount: intValue(raw["minVoteCount"]),
            sortBy: raw["sortBy"] as? String ?? "popularity.desc"
        )
    }

    // Firestore numbers arrive as Int, Int64, Double, or NSNumber.
    private func intValue(_ raw: Any?) -> Int? {
        if let i = raw as? Int { return i }
        if let n = raw as? NSNumber { return n.intValue }
        return nil
    }

    private func doubleValue(_ raw: Any?) -> Double? {
        if let d = raw as? Double { return d }
        if let n = raw as? NSNumber { return n.doubleValue }
        return nil
    }

    private func intArray(_ raw: Any?) -> [Int] {
        if let ints = raw as? [Int] { return ints }
        if let numbers = raw as? [NSNumber] { return numbers.map { $0.intValue } }
        return []
    }
}
