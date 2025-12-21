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
}

struct FirebaseListService: ListService {
    private var db: Firestore {
        guard FirebaseApp.app() != nil else {
            fatalError("Firebase is not initialized. Make sure FirebaseApp.configure() is called.")
        }
        return Firestore.firestore()
    }
    
    func createList(_ list: ShowList, for userID: String) async throws {
        let listData: [String: Any] = [
            "name": list.name,
            "showIDs": list.showIDs,
            "createdAt": Timestamp(date: list.createdAt),
            "isDefault": list.isDefault,
            "userId": userID
        ]
        
        try await db.collection("list").document(list.id).setData(listData)
    }
    
    func fetchLists(for userID: String) async throws -> [ShowList] {
        let query = db.collection("list")
            .whereField("userId", isEqualTo: userID)
        
        let snapshot = try await query.getDocuments()
        
        var lists: [ShowList] = []
        
        for document in snapshot.documents {
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
            
            let list = ShowList(
                id: document.documentID,
                name: name,
                showIDs: showIDs,
                createdAt: createdAt,
                isDefault: isDefault
            )
            
            lists.append(list)
        }
        
        return lists
    }
    
    func updateList(_ list: ShowList, for userID: String) async throws {
        try await db.collection("list").document(list.id).updateData([
            "name": list.name,
            "showIDs": list.showIDs
        ])
    }
    
    func deleteList(_ list: ShowList, for userID: String) async throws {
        try await db.collection("list").document(list.id).delete()
    }
}

