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
}

struct FirebaseListService: ListService {
    private var db: Firestore {
        guard FirebaseApp.app() != nil else {
            fatalError("Firebase is not initialized. Make sure FirebaseApp.configure() is called.")
        }
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
        
        print("📝 FirebaseListService.createList - Saving list '\(list.name)' with id: \(list.id)")
        print("📝 List data: name=\(list.name), ownerID=\(finalOwnerID), contributorIDs=\(list.contributorIDs)")
        
        try await db.collection("list").document(list.id).setData(listData)
        print("✅ FirebaseListService.createList - Successfully saved list '\(list.name)' to Firebase")
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
                print("⚠️ Skipping list document \(document.documentID) - missing name field")
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
                print("⚠️ List \(document.documentID) showIDs converted from [Any] - found \(showIDs.count) valid IDs")
            } else {
                print("⚠️ Skipping list document \(document.documentID) - invalid showIDs field: \(data["showIDs"] ?? "nil")")
                continue
            }
            
            print("📋 Loaded list '\(name)' with \(showIDs.count) shows: \(showIDs)")
            
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
}

