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
        
        let listData: [String: Any] = [
            "name": list.name,
            "showIDs": list.showIDs,
            "createdAt": Timestamp(date: list.createdAt),
            "isDefault": list.isDefault,
            "ownerID": finalOwnerID,
            "contributorIDs": list.contributorIDs
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
            
            guard let name = data["name"] as? String else {
                continue
            }
            
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
                continue
            }
            
            
            let createdAt: Date
            if let timestamp = data["createdAt"] as? Timestamp {
                createdAt = timestamp.dateValue()
            } else {
                createdAt = Date()
            }
            
            let isDefault = data["isDefault"] as? Bool ?? false
            
            // Get ownerID - support both old format (userId) and new format (ownerID)
            let ownerID: String
            if let owner = data["ownerID"] as? String {
                ownerID = owner
            } else if let userId = data["userId"] as? String {
                ownerID = userId // Legacy support
                // Update the document to have ownerID for backwards compatibility
                try? await db.collection("list").document(document.documentID).updateData([
                    "ownerID": userId,
                    "contributorIDs": []
                ])
            } else {
                // No owner found - use current user and update the document
                ownerID = userID
                try? await db.collection("list").document(document.documentID).updateData([
                    "ownerID": userID,
                    "contributorIDs": []
                ])
            }
            
            // Get contributorIDs
            let contributorIDs: [String]
            if let contributors = data["contributorIDs"] as? [String] {
                contributorIDs = contributors
            } else {
                contributorIDs = []
            }
            
            let list = ShowList(
                id: document.documentID,
                name: name,
                showIDs: showIDs,
                createdAt: createdAt,
                isDefault: isDefault,
                ownerID: ownerID,
                contributorIDs: contributorIDs
            )
            
            lists.append(list)
        }
        
        return lists
    }
    
    func updateList(_ list: ShowList, for userID: String) async throws {
        try await db.collection("list").document(list.id).updateData([
            "name": list.name,
            "showIDs": list.showIDs,
            "contributorIDs": list.contributorIDs
        ])
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

