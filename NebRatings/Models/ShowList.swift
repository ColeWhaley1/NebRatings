//
//  ShowList.swift
//  NebRatings
//
//  Created by Cole Whaley on 11/29/25.
//

import Foundation

struct ShowList: Identifiable, Hashable, Codable {
    let id: String
    var name: String
    var showIDs: [Int] // TMDB IDs of shows in this list
    var createdAt: Date
    var isDefault: Bool // For the default "To Watch" list
    let ownerID: String // User ID of the list owner
    var contributorIDs: [String] // User IDs of contributors who can edit the list
    
    init(id: String = UUID().uuidString, name: String, showIDs: [Int] = [], createdAt: Date = Date(), isDefault: Bool = false, ownerID: String = "", contributorIDs: [String] = []) {
        self.id = id
        self.name = name
        self.showIDs = showIDs
        self.createdAt = createdAt
        self.isDefault = isDefault
        self.ownerID = ownerID
        self.contributorIDs = contributorIDs
    }
    
    // Check if a user can edit this list
    func canEdit(userID: String) -> Bool {
        return ownerID == userID || contributorIDs.contains(userID)
    }
}

