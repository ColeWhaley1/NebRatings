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
    /// Nil = entire show. [1,2,3] = specific seasons. Only relevant for series; ignored for movies.
    /// Backwards compatible: existing refs decode with nil (entire show).
    let seasons: [Int]?
    
    init(id: Int, category: Show.Category, seasons: [Int]? = nil) {
        self.id = id
        self.category = category
        self.seasons = seasons
    }
    
    
    /// Display label for list UI, e.g. "Entire show" or "Seasons 1, 2, 3"
    var seasonsLabel: String? {
        guard category == .series, let seasons = seasons, !seasons.isEmpty else { return nil }
        let sorted = seasons.sorted()
        if sorted.count == 1 {
            return "Season \(sorted[0])"
        }
        return "Seasons \(sorted.map { String($0) }.joined(separator: ", "))"
    }
    
    var isEntireShow: Bool {
        seasons == nil || seasons?.isEmpty == true
    }
}

/// Who can see a list. Raw values are the Firestore representation.
/// Enforce at every display surface: `.publicList` → anyone, `.friendsOnly` →
/// the owner's friends, `.privateList` → owner + contributors only.
enum ListVisibility: String, Codable, CaseIterable, Identifiable {
    case publicList = "public"
    case friendsOnly = "friends"
    case privateList = "private"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .publicList: return "Public"
        case .friendsOnly: return "Friends Only"
        case .privateList: return "Private"
        }
    }

    var icon: String {
        switch self {
        case .publicList: return "globe"
        case .friendsOnly: return "person.2.fill"
        case .privateList: return "lock.fill"
        }
    }

    var explanation: String {
        switch self {
        case .publicList: return "Anyone can see this list on your profile."
        case .friendsOnly: return "Only your friends can see this list."
        case .privateList: return "Only you and contributors can see this list."
        }
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
    /// When true, remove the show from this list when the user reviews it. Only applies when contributorIDs.isEmpty (single-owner list).
    var autoRemoveOnReview: Bool
    /// Who can see this list. Existing lists decode as `.privateList` (the
    /// pre-feature behavior: only owner + contributors ever saw them).
    var visibility: ListVisibility

    enum CodingKeys: String, CodingKey {
        case id, name, showReferences, showIDs, createdAt, isDefault, ownerID, userId, contributorIDs, autoRemoveOnReview, visibility
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        if let refs = try container.decodeIfPresent([ShowReference].self, forKey: .showReferences) {
            showReferences = refs
        } else if let ids = try container.decodeIfPresent([Int].self, forKey: .showIDs) {
            showReferences = ids.map { ShowReference(id: $0, category: .movie) }
        } else {
            showReferences = []
        }
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        isDefault = try container.decode(Bool.self, forKey: .isDefault)
        let owner = try container.decodeIfPresent(String.self, forKey: .ownerID)
        let legacyOwner = try container.decodeIfPresent(String.self, forKey: .userId)
        ownerID = owner ?? legacyOwner ?? ""
        contributorIDs = try container.decodeIfPresent([String].self, forKey: .contributorIDs) ?? []
        autoRemoveOnReview = try container.decodeIfPresent(Bool.self, forKey: .autoRemoveOnReview) ?? false
        visibility = try container.decodeIfPresent(ListVisibility.self, forKey: .visibility) ?? .privateList
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(showReferences, forKey: .showReferences)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(isDefault, forKey: .isDefault)
        try container.encode(ownerID, forKey: .ownerID)
        try container.encode(contributorIDs, forKey: .contributorIDs)
        try container.encode(autoRemoveOnReview, forKey: .autoRemoveOnReview)
        try container.encode(visibility, forKey: .visibility)
    }
    
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
         contributorIDs: [String] = [],
         autoRemoveOnReview: Bool = false,
         visibility: ListVisibility = .privateList) {
        self.id = id
        self.name = name
        self.showReferences = showReferences
        self.createdAt = createdAt
        self.isDefault = isDefault
        self.ownerID = ownerID
        self.contributorIDs = contributorIDs
        self.autoRemoveOnReview = autoRemoveOnReview
        self.visibility = visibility
    }

    // Backwards compatibility initializer for old format
    init(id: String = UUID().uuidString,
         name: String,
         showIDs: [Int],
         createdAt: Date = Date(),
         isDefault: Bool = false,
         ownerID: String = "",
         contributorIDs: [String] = [],
         autoRemoveOnReview: Bool = false,
         visibility: ListVisibility = .privateList) {
        self.id = id
        self.name = name
        // Convert old showIDs to showReferences (category will be inferred later)
        self.showReferences = showIDs.map { ShowReference(id: $0, category: .movie) }
        self.createdAt = createdAt
        self.isDefault = isDefault
        self.ownerID = ownerID
        self.contributorIDs = contributorIDs
        self.autoRemoveOnReview = autoRemoveOnReview
        self.visibility = visibility
    }
    
    // Check if a user can edit this list
    func canEdit(userID: String) -> Bool {
        return ownerID == userID || contributorIDs.contains(userID)
    }

    /// Single source of truth for visibility enforcement — every surface that
    /// displays someone else's lists must gate on this. Owner + contributors
    /// always see their own lists; others depend on the visibility level.
    /// `isFriendOfOwner`: whether the viewer and the list owner are friends.
    func isVisible(to viewerID: String?, isFriendOfOwner: Bool) -> Bool {
        if let viewerID, canEdit(userID: viewerID) { return true }
        switch visibility {
        case .publicList: return true
        case .friendsOnly: return isFriendOfOwner
        case .privateList: return false
        }
    }
    
    // Check if a show is in this list. Matches on id (TMDB ids are unique per media).
    func contains(show: Show) -> Bool {
        return showReferences.contains { $0.id == show.id }
    }
    
    // Check if a show ID is in this list (backwards compatibility)
    func contains(showID: Int) -> Bool {
        return showReferences.contains { $0.id == showID }
    }
}

