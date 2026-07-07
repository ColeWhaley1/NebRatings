//
//  ActivityService.swift
//  NebRatings
//
//  Persists and fetches feed events that have no other queryable record
//  (list creations, list adds, review updates). Rated events are derived
//  from reviews at read time and never stored here.
//

import Foundation
import FirebaseFirestore

protocol ActivityService {
    func record(_ activity: Activity) async throws
    /// Most recent events, newest first.
    func fetchRecent(limit: Int) async throws -> [Activity]
    /// Deletes every event for a list — called when a list turns private
    /// (its history must stop being visible) or is deleted.
    func removeListEvents(listID: String) async throws
}

struct FirebaseActivityService: ActivityService {
    private var db: Firestore { Firestore.firestore() }
    private let collection = "activity"

    func record(_ activity: Activity) async throws {
        var data: [String: Any] = [
            "userID": activity.userID,
            "username": activity.username,
            "kind": activity.kind.rawValue,
            "timestamp": Timestamp(date: activity.timestamp)
        ]
        if let showID = activity.showID { data["showID"] = showID }
        if let showTitle = activity.showTitle { data["showTitle"] = showTitle }
        if let showCategory = activity.showCategory { data["showCategory"] = showCategory.rawValue }
        if let rating = activity.rating { data["rating"] = rating }
        if let season = activity.season { data["season"] = season }
        if let listID = activity.listID { data["listID"] = listID }
        if let listName = activity.listName { data["listName"] = listName }
        if let listVisibility = activity.listVisibility { data["listVisibility"] = listVisibility.rawValue }

        try await db.collection(collection).document(activity.id).setData(data)
    }

    func removeListEvents(listID: String) async throws {
        let snapshot = try await db.collection(collection)
            .whereField("listID", isEqualTo: listID)
            .getDocuments()
        guard !snapshot.documents.isEmpty else { return }
        let batch = db.batch()
        for document in snapshot.documents {
            batch.deleteDocument(document.reference)
        }
        try await batch.commit()
    }

    func fetchRecent(limit: Int) async throws -> [Activity] {
        let snapshot = try await db.collection(collection)
            .order(by: "timestamp", descending: true)
            .limit(to: limit)
            .getDocuments()

        return snapshot.documents.compactMap { document in
            let data = document.data()
            guard let userID = data["userID"] as? String,
                  let username = data["username"] as? String,
                  let kindRaw = data["kind"] as? String,
                  let kind = Activity.Kind(rawValue: kindRaw),
                  let timestamp = (data["timestamp"] as? Timestamp)?.dateValue()
            else { return nil }

            return Activity(
                id: document.documentID,
                userID: userID,
                username: username,
                kind: kind,
                timestamp: timestamp,
                showID: (data["showID"] as? Int) ?? (data["showID"] as? NSNumber)?.intValue,
                showTitle: data["showTitle"] as? String,
                showCategory: (data["showCategory"] as? String).flatMap { Show.Category(rawValue: $0) },
                rating: (data["rating"] as? Double) ?? (data["rating"] as? NSNumber)?.doubleValue,
                season: (data["season"] as? Int) ?? (data["season"] as? NSNumber)?.intValue,
                listID: data["listID"] as? String,
                listName: data["listName"] as? String,
                listVisibility: (data["listVisibility"] as? String).flatMap { ListVisibility(rawValue: $0) }
            )
        }
    }
}
