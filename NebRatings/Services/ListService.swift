//
//  ListService.swift
//  NebRatings
//
//  Created by Cole Whaley on 11/29/25.
//

import Foundation
import FirebaseFirestore
import FirebaseAuth
import FirebaseCore

protocol ListService {
    func createList(_ list: ShowList, for userID: String) async throws
    func fetchLists(for userID: String) async throws -> [ShowList]
    func updateList(_ list: ShowList, for userID: String) async throws
    func deleteList(_ list: ShowList, for userID: String) async throws
    func addContributor(_ contributorID: String, to listID: String, for ownerID: String) async throws
    func removeContributor(_ contributorID: String, from listID: String, for ownerID: String) async throws
    func deleteAllListsByOwner(ownerID: String) async throws
    func removeUserFromAllLists(contributorID: String) async throws
    /// Another user's lists that the viewer may see: always the owner's
    /// public lists, plus friends-only lists when `includeFriendsOnly`.
    /// Two visibility-scoped queries (not one broad owner query) so each is
    /// provably allowed under per-document security rules.
    func fetchVisibleLists(ownerID: String, includeFriendsOnly: Bool) async throws -> [ShowList]
}

struct FirebaseListService: ListService {
    private var db: Firestore {
        // Return Firestore instance - errors will be handled at the call site if Firebase isn't initialized
        // This prevents app crashes and allows graceful error handling
        return Firestore.firestore()
    }
    
    func createList(_ list: ShowList, for userID: String) async throws {
        // Ensure ownerID is set - use the list's ownerID if provided, otherwise use the userID parameter
        let finalOwnerID = list.ownerID.isEmpty ? userID : list.ownerID
        
        // Convert showReferences to Firestore format
        let showReferencesData = list.showReferences.map { ref -> [String: Any] in
            var data: [String: Any] = [
                "id": ref.id,
                "category": ref.category.rawValue
            ]
            if let seasons = ref.seasons, !seasons.isEmpty {
                data["seasons"] = seasons
            }
            return data
        }
        
        let listData: [String: Any] = [
            "name": list.name,
            "showReferences": showReferencesData,
            "showIDs": list.showIDs, // Keep for backwards compatibility
            "createdAt": Timestamp(date: list.createdAt),
            "isDefault": list.isDefault,
            "ownerID": finalOwnerID,
            "contributorIDs": list.contributorIDs,
            "autoRemoveOnReview": list.autoRemoveOnReview,
            "visibility": list.visibility.rawValue
        ]
        
        
        try await db.collection("list").document(list.id).setData(listData)
    }
    
    func fetchLists(for userID: String) async throws -> [ShowList] {
        // Fetch lists where user is owner (new format)
        let ownerQuery = db.collection("list")
            .whereField("ownerID", isEqualTo: userID)
        
        let ownerSnapshot = try await ownerQuery.getDocuments()
        
        // Fetch lists where user is owner (legacy format with userId field)
        let legacyOwnerQuery = db.collection("list")
            .whereField("userId", isEqualTo: userID)
        
        let legacyOwnerSnapshot = try await legacyOwnerQuery.getDocuments()
        
        // Fetch lists where user is contributor
        let contributorQuery = db.collection("list")
            .whereField("contributorIDs", arrayContains: userID)
        
        let contributorSnapshot = try await contributorQuery.getDocuments()
        
        // Combine and deduplicate
        var documentIDs = Set<String>()
        var allDocuments: [QueryDocumentSnapshot] = []
        
        for document in ownerSnapshot.documents {
            if !documentIDs.contains(document.documentID) {
                documentIDs.insert(document.documentID)
                allDocuments.append(document)
            }
        }
        
        for document in legacyOwnerSnapshot.documents {
            if !documentIDs.contains(document.documentID) {
                documentIDs.insert(document.documentID)
                allDocuments.append(document)
            }
        }
        
        for document in contributorSnapshot.documents {
            if !documentIDs.contains(document.documentID) {
                documentIDs.insert(document.documentID)
                allDocuments.append(document)
            }
        }
        
        var lists: [ShowList] = []

        for document in allDocuments {
            let data = document.data()

            // Legacy self-heal: docs without ownerID (old `userId` format) get
            // ownerID persisted. Only possible on the user's own lists — this
            // fetch path only returns docs they own or contribute to.
            if data["ownerID"] == nil {
                let legacyOwner = (data["userId"] as? String) ?? userID
                try? await db.collection("list").document(document.documentID).updateData([
                    "ownerID": legacyOwner,
                    "contributorIDs": []
                ])
            }

            if let list = parseList(document: document, fallbackOwnerID: userID) {
                lists.append(list)
            }
        }

        return lists
    }

    func fetchVisibleLists(ownerID: String, includeFriendsOnly: Bool) async throws -> [ShowList] {
        var visibilities = [ListVisibility.publicList.rawValue]
        if includeFriendsOnly {
            visibilities.append(ListVisibility.friendsOnly.rawValue)
        }

        var seen = Set<String>()
        var lists: [ShowList] = []

        for visibility in visibilities {
            let snapshot = try await db.collection("list")
                .whereField("ownerID", isEqualTo: ownerID)
                .whereField("visibility", isEqualTo: visibility)
                .getDocuments()
            for document in snapshot.documents where !seen.contains(document.documentID) {
                seen.insert(document.documentID)
                if let list = parseList(document: document, fallbackOwnerID: ownerID) {
                    lists.append(list)
                }
            }
        }

        return lists.sorted { $0.createdAt > $1.createdAt }
    }

    /// Parses one Firestore list document. Pure — no healing writes — so it's
    /// safe for documents the current user doesn't own.
    private func parseList(document: QueryDocumentSnapshot, fallbackOwnerID: String) -> ShowList? {
        let data = document.data()

        guard let name = data["name"] as? String else {
            return nil
        }

        // Try to read showReferences (new format) first
        var showReferences: [ShowReference] = []
        if let referencesArray = data["showReferences"] as? [[String: Any]] {
            showReferences = referencesArray.compactMap { refData in
                // Firestore may return numbers as Int, Int64, or NSNumber
                let id: Int?
                if let i = refData["id"] as? Int {
                    id = i
                } else if let n = refData["id"] as? NSNumber {
                    id = n.intValue
                } else {
                    id = nil
                }
                guard let id = id else { return nil }
                let category: Show.Category
                if let categoryString = refData["category"] as? String,
                   let parsed = Show.Category(rawValue: categoryString) {
                    category = parsed
                } else {
                    category = .movie
                }
                let seasons: [Int]?
                if let seasonsArray = refData["seasons"] as? [Int] {
                    seasons = seasonsArray.isEmpty ? nil : seasonsArray
                } else if let seasonsArray = refData["seasons"] as? [NSNumber] {
                    let parsed = seasonsArray.map { $0.intValue }
                    seasons = parsed.isEmpty ? nil : parsed
                } else {
                    seasons = nil
                }
                return ShowReference(id: id, category: category, seasons: seasons)
            }
        }

        // If no showReferences found, fall back to showIDs (backwards compatibility)
        if showReferences.isEmpty {
            // Properly convert showIDs array - Firestore may store as NSNumber
            let showIDs: [Int]
            if let showIDsArray = data["showIDs"] as? [Int] {
                showIDs = showIDsArray
            } else if let showIDsArray = data["showIDs"] as? [NSNumber] {
                showIDs = showIDsArray.map { $0.intValue }
            } else if let showIDsArray = data["showIDs"] as? [Any] {
                showIDs = showIDsArray.compactMap { value in
                    if let intValue = value as? Int {
                        return intValue
                    } else if let nsNumber = value as? NSNumber {
                        return nsNumber.intValue
                    }
                    return nil
                }
            } else {
                return nil
            }

            // Convert old showIDs to showReferences (category will be inferred when loading)
            // Default to .movie, but this will be corrected when the show is actually loaded
            showReferences = showIDs.map { ShowReference(id: $0, category: .movie) }
        }

        let createdAt: Date
        if let timestamp = data["createdAt"] as? Timestamp {
            createdAt = timestamp.dateValue()
        } else {
            createdAt = Date()
        }

        let isDefault = data["isDefault"] as? Bool ?? false

        // Owner - support both old format (userId) and new format (ownerID)
        let ownerID = (data["ownerID"] as? String) ?? (data["userId"] as? String) ?? fallbackOwnerID

        let contributorIDs = data["contributorIDs"] as? [String] ?? []

        // Get autoRemoveOnReview (optional - backwards compatible, default false)
        let autoRemoveOnReview = data["autoRemoveOnReview"] as? Bool ?? false

        // Visibility (optional - pre-feature lists default to private,
        // matching their historical owner/contributor-only exposure)
        let visibility = (data["visibility"] as? String).flatMap { ListVisibility(rawValue: $0) } ?? .privateList

        return ShowList(
            id: document.documentID,
            name: name,
            showReferences: showReferences,
            createdAt: createdAt,
            isDefault: isDefault,
            ownerID: ownerID,
            contributorIDs: contributorIDs,
            autoRemoveOnReview: autoRemoveOnReview,
            visibility: visibility
        )
    }
    
    func updateList(_ list: ShowList, for userID: String) async throws {
        // Convert showReferences to Firestore format
        let showReferencesData = list.showReferences.map { ref -> [String: Any] in
            var data: [String: Any] = [
                "id": ref.id,
                "category": ref.category.rawValue
            ]
            if let seasons = ref.seasons, !seasons.isEmpty {
                data["seasons"] = seasons
            }
            return data
        }
        
        // Use setData with merge to ensure the write succeeds even if the document
        // was created elsewhere or there are sync delays; updateData fails if doc doesn't exist.
        try await db.collection("list").document(list.id).setData([
            "name": list.name,
            "showReferences": showReferencesData,
            "showIDs": list.showIDs, // Keep for backwards compatibility
            "contributorIDs": list.contributorIDs,
            "autoRemoveOnReview": list.autoRemoveOnReview,
            "visibility": list.visibility.rawValue
        ], merge: true)
    }
    
    func deleteList(_ list: ShowList, for userID: String) async throws {
        try await db.collection("list").document(list.id).delete()
    }
    
    func addContributor(_ contributorID: String, to listID: String, for ownerID: String) async throws {
        let listRef = db.collection("list").document(listID)
        
        // Use arrayUnion to add contributor if not already present
        try await listRef.updateData([
            "contributorIDs": FieldValue.arrayUnion([contributorID])
        ])
    }
    
    func removeContributor(_ contributorID: String, from listID: String, for ownerID: String) async throws {
        let listRef = db.collection("list").document(listID)
        
        // Use arrayRemove to remove contributor
        try await listRef.updateData([
            "contributorIDs": FieldValue.arrayRemove([contributorID])
        ])
    }
    
    func deleteAllListsByOwner(ownerID: String) async throws {
        // Query all lists owned by this user (both new and legacy formats)
        let ownerQuery = db.collection("list")
            .whereField("ownerID", isEqualTo: ownerID)
        
        let ownerSnapshot = try await ownerQuery.getDocuments()
        
        // Also check legacy format
        let legacyOwnerQuery = db.collection("list")
            .whereField("userId", isEqualTo: ownerID)
        
        let legacyOwnerSnapshot = try await legacyOwnerQuery.getDocuments()
        
        // Combine document IDs (deduplicate)
        var documentIDs = Set<String>()
        for document in ownerSnapshot.documents {
            documentIDs.insert(document.documentID)
        }
        for document in legacyOwnerSnapshot.documents {
            documentIDs.insert(document.documentID)
        }
        
        // Delete all lists in batches
        let batch = db.batch()
        var batchCount = 0
        let maxBatchSize = 500 // Firestore batch limit
        
        for documentID in documentIDs {
            let listRef = db.collection("list").document(documentID)
            batch.deleteDocument(listRef)
            batchCount += 1
            
            // Commit batch if we reach the limit
            if batchCount >= maxBatchSize {
                try await batch.commit()
                batchCount = 0
            }
        }
        
        // Commit any remaining deletions
        if batchCount > 0 {
            try await batch.commit()
        }
    }
    
    func removeUserFromAllLists(contributorID: String) async throws {
        // Query all lists where this user is a contributor
        let contributorQuery = db.collection("list")
            .whereField("contributorIDs", arrayContains: contributorID)
        
        let snapshot = try await contributorQuery.getDocuments()
        
        // Remove the user from all lists in batches
        let batch = db.batch()
        var batchCount = 0
        let maxBatchSize = 500 // Firestore batch limit
        
        for document in snapshot.documents {
            let listRef = db.collection("list").document(document.documentID)
            
            // Remove the contributor from the array
            batch.updateData([
                "contributorIDs": FieldValue.arrayRemove([contributorID])
            ], forDocument: listRef)
            
            batchCount += 1
            
            // Commit batch if we reach the limit
            if batchCount >= maxBatchSize {
                try await batch.commit()
                batchCount = 0
            }
        }
        
        // Commit any remaining updates
        if batchCount > 0 {
            try await batch.commit()
        }
    }
}

