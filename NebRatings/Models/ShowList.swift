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
    
    init(id: String = UUID().uuidString, name: String, showIDs: [Int] = [], createdAt: Date = Date(), isDefault: Bool = false) {
        self.id = id
        self.name = name
        self.showIDs = showIDs
        self.createdAt = createdAt
        self.isDefault = isDefault
    }
}

