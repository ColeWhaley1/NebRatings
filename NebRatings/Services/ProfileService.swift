//
//  ProfileService.swift
//  NebRatings
//
//  Created by Cole Whaley on 11/29/25.
//

import Foundation
import FirebaseFirestore
import FirebaseAuth
import FirebaseCore

protocol ProfileService {
    func createProfile(userID: String, name: String) async throws
    func updateProfile(userID: String, name: String) async throws
    func updateAvatar(userID: String, emoji: String?) async throws
    func fetchCurrentUser() async throws -> UserProfile
    func fetchProfile(userID: String) async throws -> UserProfile?
    func fetchProfiles(userIDs: [String]) async throws -> [UserProfile]
    func fetchReviews(for userID: String) async throws -> [Review]
    func searchUsers(byName name: String) async throws -> [UserProfile]
    func isUsernameAvailable(_ name: String, excludingUserID: String?) async throws -> Bool
    func deleteProfile(userID: String) async throws
    func incrementCriticAggregate(userID: String, sumDelta: Double, countDelta: Int) async throws
    func setCriticAggregate(userID: String, sum: Double, count: Int) async throws
    /// Adjusts the per-genre review tally by the given deltas (e.g. +1 per genre on a
    /// new review, −1 on delete). Only touches the named genre keys.
    func incrementGenreCounts(userID: String, deltas: [String: Int]) async throws
    /// Replaces the whole genre tally — used for the one-time backfill.
    func setGenreCounts(userID: String, counts: [String: Int]) async throws
}

struct FirebaseProfileService: ProfileService {
    private var db: Firestore {
        // Return Firestore instance - errors will be handled at the call site if Firebase isn't initialized
        // This prevents app crashes and allows graceful error handling
        return Firestore.firestore()
    }
    
    func createProfile(userID: String, name: String) async throws {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        guard !trimmedName.isEmpty else {
            throw NSError(domain: "ProfileService", code: -4, userInfo: [NSLocalizedDescriptionKey: "Name cannot be empty"])
        }
        
        // Check if username is available
        let isAvailable = try await isUsernameAvailable(trimmedName, excludingUserID: nil)
        guard isAvailable else {
            throw NSError(domain: "ProfileService", code: -3, userInfo: [NSLocalizedDescriptionKey: "Username is already taken. Please choose a different name."])
        }
        
        let normalizedName = trimmedName.lowercased()
        let profileData: [String: Any] = [
            "username": trimmedName,
            "usernameLowercase": normalizedName  // Store lowercase version for case-insensitive uniqueness checks
        ]
        
        try await db.collection("profile").document(userID).setData(profileData)
    }
    
    func updateProfile(userID: String, name: String) async throws {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        guard !trimmedName.isEmpty else {
            throw NSError(domain: "ProfileService", code: -4, userInfo: [NSLocalizedDescriptionKey: "Name cannot be empty"])
        }
        
        // Check if username is available (excluding current user)
        let isAvailable = try await isUsernameAvailable(trimmedName, excludingUserID: userID)
        guard isAvailable else {
            throw NSError(domain: "ProfileService", code: -3, userInfo: [NSLocalizedDescriptionKey: "Username is already taken. Please choose a different name."])
        }
        
        let normalizedName = trimmedName.lowercased()
        try await db.collection("profile").document(userID).updateData([
            "username": trimmedName,
            "usernameLowercase": normalizedName  // Update lowercase version
        ])
    }
    
    func updateAvatar(userID: String, emoji: String?) async throws {
        let data: [String: Any] = ["avatarEmoji": emoji as Any? ?? NSNull()]
        try await db.collection("profile").document(userID).setData(data, merge: true)
    }

    func fetchCurrentUser() async throws -> UserProfile {
        guard let userID = Auth.auth().currentUser?.uid else {
            throw NSError(domain: "ProfileService", code: -1, userInfo: [NSLocalizedDescriptionKey: "No authenticated user"])
        }

        let document = try await db.collection("profile").document(userID).getDocument()

        guard document.exists,
              let data = document.data(),
              let username = data["username"] as? String else {
            throw NSError(domain: "ProfileService", code: -2, userInfo: [NSLocalizedDescriptionKey: "Profile not found"])
        }
        return UserProfile(
            id: userID,
            username: username,
            avatarEmoji: data["avatarEmoji"] as? String,
            criticDeltaSum: data["criticDeltaSum"] as? Double,
            criticDeltaCount: data["criticDeltaCount"] as? Int,
            genreCounts: parseGenreCounts(data["genreCounts"])
        )
    }

    func fetchProfile(userID: String) async throws -> UserProfile? {
        let document = try await db.collection("profile").document(userID).getDocument()

        guard document.exists,
              let data = document.data(),
              let username = data["username"] as? String else {
            return nil
        }
        return UserProfile(
            id: userID,
            username: username,
            avatarEmoji: data["avatarEmoji"] as? String,
            criticDeltaSum: data["criticDeltaSum"] as? Double,
            criticDeltaCount: data["criticDeltaCount"] as? Int,
            genreCounts: parseGenreCounts(data["genreCounts"])
        )
    }

    func fetchProfiles(userIDs: [String]) async throws -> [UserProfile] {
        guard !userIDs.isEmpty else { return [] }

        var results: [UserProfile] = []
        // Firestore `in` queries cap at 30 values; chunk to stay safe.
        for chunk in userIDs.chunked(into: 30) {
            let snapshot = try await db.collection("profile")
                .whereField(FieldPath.documentID(), in: chunk)
                .getDocuments()
            for document in snapshot.documents {
                let data = document.data()
                guard let username = data["username"] as? String else { continue }
                results.append(UserProfile(
                    id: document.documentID,
                    username: username,
                    avatarEmoji: data["avatarEmoji"] as? String,
                    criticDeltaSum: data["criticDeltaSum"] as? Double,
                    criticDeltaCount: data["criticDeltaCount"] as? Int,
                    genreCounts: parseGenreCounts(data["genreCounts"])
                ))
            }
        }
        return results
    }

    func incrementCriticAggregate(userID: String, sumDelta: Double, countDelta: Int) async throws {
        try await db.collection("profile").document(userID).setData([
            "criticDeltaSum": FieldValue.increment(sumDelta),
            "criticDeltaCount": FieldValue.increment(Int64(countDelta))
        ], merge: true)
    }

    func setCriticAggregate(userID: String, sum: Double, count: Int) async throws {
        try await db.collection("profile").document(userID).setData([
            "criticDeltaSum": sum,
            "criticDeltaCount": count
        ], merge: true)
    }

    func incrementGenreCounts(userID: String, deltas: [String: Int]) async throws {
        // Build per-key increments. FieldPath (not dotted-string) keys so genre
        // names containing "." or other special characters can't corrupt the path —
        // TMDB names like "Sci-Fi & Fantasy" / "War & Politics" stay intact.
        var data: [AnyHashable: Any] = [:]
        for (genre, delta) in deltas where delta != 0 {
            data[FieldPath(["genreCounts", genre])] = FieldValue.increment(Int64(delta))
        }
        guard !data.isEmpty else { return }
        try await db.collection("profile").document(userID).updateData(data)
    }

    func setGenreCounts(userID: String, counts: [String: Int]) async throws {
        // Replace the whole map (merge:true only merges at the top level, so the
        // genreCounts field is overwritten wholesale). Writing even an empty map
        // marks the tally as "computed" so the one-time backfill never re-runs.
        try await db.collection("profile").document(userID).setData([
            "genreCounts": counts
        ], merge: true)
    }

    /// Firestore returns map values as `NSNumber`-backed `Any`; normalize to `[String: Int]`.
    /// Returns nil when the field is absent so callers can detect "needs backfill".
    private func parseGenreCounts(_ raw: Any?) -> [String: Int]? {
        guard let dict = raw as? [String: Any] else { return nil }
        var result: [String: Int] = [:]
        for (key, value) in dict {
            if let intValue = value as? Int {
                result[key] = intValue
            } else if let number = value as? NSNumber {
                result[key] = number.intValue
            }
        }
        return result
    }

    func fetchReviews(for userID: String) async throws -> [Review] {
        // Query Firestore for user-specific reviews
        let query = db.collection("review")
            .whereField("userId", isEqualTo: userID)
            .limit(to: 100)
        
        let snapshot = try await query.getDocuments()
        
        // Map Firestore documents to Review models
        var reviews: [Review] = []
        
        for document in snapshot.documents {
            let data = document.data()
            
            // Parse all fields matching Review struct structure
            // Handle both old format (showID as String/UUID) and new format (showID as Int)
            let showID: Int
            if let showIDInt = data["showID"] as? Int {
                showID = showIDInt
            } else if let showIDString = data["showID"] as? String {
                // Legacy format - try to extract from showTMDBID or default
                if let tmdbID = data["showTMDBID"] as? Int {
                    showID = tmdbID
                } else {
                    continue
                }
            } else {
                continue
            }
            
            guard let showTitle = data["showTitle"] as? String,
                  let author = data["author"] as? String,
                  let comment = data["comment"] as? String,
                  let nebRating = data["nebRating"] as? Double else {
                continue
            }
            
            // Parse timestamp
            let timestamp: Date
            if let timestampValue = data["timestamp"] as? Timestamp {
                timestamp = timestampValue.dateValue()
            } else {
                // Fallback to current date if timestamp is missing
                timestamp = Date()
            }
            
            // Parse id from document ID
            let id = UUID(uuidString: document.documentID) ?? UUID()
            
            // Parse category - handle both old reviews (without category) and new reviews (with category)
            let showCategory: Show.Category
            if let categoryString = data["showCategory"] as? String,
               let category = Show.Category(rawValue: categoryString) {
                showCategory = category
            } else {
                // Fallback: default to movie for existing reviews without category
                showCategory = .movie
            }
            
            // Parse season (optional field) - for season-specific reviews
            let season: Int? = data["season"] as? Int

            // Author's userId — this query is keyed by userId so fall back to the requested userID.
            let authorID = (data["userId"] as? String) ?? userID

            // Create Review model matching the struct exactly
            let review = Review(
                id: id,
                showID: showID,
                showTitle: showTitle,
                showCategory: showCategory,
                author: author,
                authorID: authorID,
                comment: comment,
                nebRating: nebRating,
                timestamp: timestamp,
                season: season
            )
            
            reviews.append(review)
        }
        
        return reviews
    }
    
    func searchUsers(byName name: String) async throws -> [UserProfile] {
        guard !name.trimmingCharacters(in: .whitespaces).isEmpty else {
            return []
        }
        
        let searchTerm = name.trimmingCharacters(in: .whitespaces).lowercased()
        
        // Use usernameLowercase field for case-insensitive prefix search
        // This is more efficient and accurate than querying username directly
        let query = db.collection("profile")
            .whereField("usernameLowercase", isGreaterThanOrEqualTo: searchTerm)
            .whereField("usernameLowercase", isLessThanOrEqualTo: searchTerm + "\u{f8ff}")
            .limit(to: 50)
        
        let snapshot = try await query.getDocuments()
        
        var users: [UserProfile] = []
        
        for document in snapshot.documents {
            let data = document.data()
            
            // Get username (prefer new field, fall back to legacy "name" for backwards compatibility)
            var profileUsername: String? = data["username"] as? String
            if profileUsername == nil {
                profileUsername = data["name"] as? String // Legacy support
            }
            
            guard let username = profileUsername else {
                continue
            }
            
            // Case-insensitive contains check - matches if search term appears anywhere in username
            let normalizedUsername = username.lowercased()
            if normalizedUsername.contains(searchTerm) {
                users.append(UserProfile(
                    id: document.documentID,
                    username: username,
                    avatarEmoji: data["avatarEmoji"] as? String
                ))
            }
        }

        // Also check legacy profiles that might not have usernameLowercase field yet
        // Query by username field (case-sensitive, so try both lowercase and capitalized)
        let legacyQuery1 = db.collection("profile")
            .whereField("username", isGreaterThanOrEqualTo: searchTerm)
            .whereField("username", isLessThanOrEqualTo: searchTerm + "\u{f8ff}")
            .limit(to: 50)
        
        let legacySnapshot1 = try await legacyQuery1.getDocuments()
        
        for document in legacySnapshot1.documents {
            let data = document.data()
            
            // Skip if already found
            if users.contains(where: { $0.id == document.documentID }) {
                continue
            }
            
            // Skip if has usernameLowercase (already checked above)
            if data["usernameLowercase"] != nil {
                continue
            }
            
            var profileUsername: String? = data["username"] as? String
            if profileUsername == nil {
                profileUsername = data["name"] as? String
            }
            
            guard let username = profileUsername else {
                continue
            }
            
            let normalizedUsername = username.lowercased()
            if normalizedUsername.contains(searchTerm) {
                users.append(UserProfile(
                    id: document.documentID,
                    username: username,
                    avatarEmoji: data["avatarEmoji"] as? String
                ))
            }
        }

        // Remove duplicates
        var uniqueUsers: [UserProfile] = []
        var seenIDs = Set<String>()
        for user in users {
            if !seenIDs.contains(user.id) {
                seenIDs.insert(user.id)
                uniqueUsers.append(user)
            }
        }
        
        return Array(uniqueUsers.prefix(20)) // Limit to 20 results
    }
    
    func isUsernameAvailable(_ name: String, excludingUserID: String?) async throws -> Bool {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        guard !trimmedName.isEmpty else {
            return false
        }
        
        // Normalize the name for comparison (trim, lowercase)
        let normalizedName = trimmedName.lowercased()
        
        // Query using the usernameLowercase field for efficient case-insensitive lookup
        // If usernameLowercase doesn't exist (legacy profiles), fall back to checking username field
        let query = db.collection("profile")
            .whereField("usernameLowercase", isEqualTo: normalizedName)
            .limit(to: 10)
        
        let snapshot = try await query.getDocuments()
        
        // Check if any matching documents exist (excluding the current user if editing)
        for document in snapshot.documents {
            // If excludingUserID is provided and matches, this is the same user - allow it
            if let excludingID = excludingUserID, document.documentID == excludingID {
                continue
            }
            // Username is taken by someone else
            return false
        }
        
        // For legacy profiles without usernameLowercase field, we need to check manually
        // Since Firestore doesn't support case-insensitive queries, we'll fetch a batch
        // and check. For better performance with many legacy profiles, we could add
        // a Cloud Function to migrate them, but for now we'll do a limited check.
        
        // Fetch profiles without usernameLowercase field (this is a workaround - ideally
        // all profiles should have usernameLowercase, but we need backwards compatibility)
        // We'll limit this to a reasonable number to avoid performance issues
        let allProfilesQuery = db.collection("profile")
            .limit(to: 100) // Reasonable limit for legacy check
        
        let allProfilesSnapshot = try await allProfilesQuery.getDocuments()
        
        for document in allProfilesSnapshot.documents {
            // Skip if this is the user we're excluding
            if let excludingID = excludingUserID, document.documentID == excludingID {
                continue
            }
            
            let data = document.data()
            
            // Skip if this profile has usernameLowercase (already checked above)
            if data["usernameLowercase"] != nil {
                continue
            }
            
            // Check legacy profile username case-insensitively (try both "name" and "username" for backwards compatibility)
            var profileUsername: String? = data["username"] as? String
            if profileUsername == nil {
                profileUsername = data["name"] as? String // Legacy support
            }
            
            guard let username = profileUsername else {
                continue
            }
            
            let normalizedProfileUsername = username.trimmingCharacters(in: .whitespaces).lowercased()
            if normalizedProfileUsername == normalizedName {
                // Found a match in legacy profile - also update it to have usernameLowercase for future queries
                try? await db.collection("profile").document(document.documentID).updateData([
                    "username": username,
                    "usernameLowercase": normalizedProfileUsername
                ])
                return false
            }
        }
        
        return true
    }
    
    func deleteProfile(userID: String) async throws {
        guard FirebaseApp.app() != nil else {
            throw NSError(domain: "ProfileService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Firebase is not initialized"])
        }

        try await db.collection("profile").document(userID).delete()
    }
}

extension Array {
    func chunked(into size: Int) -> [[Element]] {
        guard size > 0 else { return [self] }
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}





