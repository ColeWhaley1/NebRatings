//
//  ShowList.swift
//  NebRatings
//
//  Created by Cole Whaley on 11/29/25.
//

import Foundation

struct ShowReference: Identifiable, Hashable, Codable {
    let id: Int // TMDB ID
    let category: Show.Category
    
    init(id: Int, category: Show.Category) {
        self.id = id
        self.category = category
    }
}

struct ShowList: Identifiable, Hashable, Codable {
    let id: String
    var name: String
    var showReferences: [ShowReference] // TMDB IDs with categories
    var createdAt: Date
    var isDefault: Bool // For the default "To Watch" list
    let ownerID: String // User ID of the list owner
    var contributorIDs: [String] // User IDs of contributors who can edit the list
    
    // Computed property for backwards compatibility - derives from showReferences
    var showIDs: [Int] {
        showReferences.map { $0.id }
    }
    
    init(id: String = UUID().uuidString, 
         name: String, 
         showReferences: [ShowReference] = [], 
         createdAt: Date = Date(), 
         isDefault: Bool = false, 
         ownerID: String = "", 
         contributorIDs: [String] = []) {
        self.id = id
        self.name = name
        self.showReferences = showReferences
        self.createdAt = createdAt
        self.isDefault = isDefault
        self.ownerID = ownerID
        self.contributorIDs = contributorIDs
    }
    
    // Backwards compatibility initializer for old format
    init(id: String = UUID().uuidString,
         name: String,
         showIDs: [Int],
         createdAt: Date = Date(),
         isDefault: Bool = false,
         ownerID: String = "",
         contributorIDs: [String] = []) {
        self.id = id
        self.name = name
        // Convert old showIDs to showReferences (category will be inferred later)
        self.showReferences = showIDs.map { ShowReference(id: $0, category: .movie) }
        self.createdAt = createdAt
        self.isDefault = isDefault
        self.ownerID = ownerID
        self.contributorIDs = contributorIDs
    }
    
    // Check if a user can edit this list
    func canEdit(userID: String) -> Bool {
        return ownerID == userID || contributorIDs.contains(userID)
    }
    
    // Check if a show is in this list
    func contains(show: Show) -> Bool {
        return showReferences.contains { $0.id == show.id && $0.category == show.category }
    }
    
    // Check if a show ID is in this list (backwards compatibility)
    func contains(showID: Int) -> Bool {
        return showReferences.contains { $0.id == showID }
    }
}

