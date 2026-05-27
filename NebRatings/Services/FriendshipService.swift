//
//  FriendshipService.swift
//  NebRatings
//

import Foundation
import FirebaseFirestore
import FirebaseCore

protocol FriendshipService {
    func sendRequest(from senderID: String, to recipientID: String) async throws
    func acceptRequest(currentUserID: String, otherUserID: String) async throws
    /// Used for declining incoming requests, canceling outgoing requests, and removing existing friends.
    func deleteRelationship(currentUserID: String, otherUserID: String) async throws
    func fetchRelationships(for userID: String) async throws -> [Friendship]
}

struct FirebaseFriendshipService: FriendshipService {
    private var db: Firestore { Firestore.firestore() }
    private let collection = "friendship"

    func sendRequest(from senderID: String, to recipientID: String) async throws {
        guard senderID != recipientID else {
            throw NSError(domain: "FriendshipService", code: -10, userInfo: [NSLocalizedDescriptionKey: "Cannot friend yourself"])
        }

        let docID = Friendship.documentID(senderID, recipientID)
        // NOTE: we intentionally do NOT read the doc first. Reading a non-existent
        // friendship doc fails under typical security rules (`resource` is null,
        // so any reference to `resource.data.members` fails). We just attempt
        // setData; the create rule covers the non-existent case, and any error
        // is resynced by the caller refetching relationships.
        try await db.collection(collection).document(docID).setData([
            "members": [senderID, recipientID].sorted(),
            "status": Friendship.Status.pending.rawValue,
            "requesterID": senderID,
            "createdAt": Timestamp(date: Date())
        ])
    }

    func acceptRequest(currentUserID: String, otherUserID: String) async throws {
        let docID = Friendship.documentID(currentUserID, otherUserID)
        try await db.collection(collection).document(docID).updateData([
            "status": Friendship.Status.accepted.rawValue,
            "acceptedAt": Timestamp(date: Date())
        ])
    }

    func deleteRelationship(currentUserID: String, otherUserID: String) async throws {
        let docID = Friendship.documentID(currentUserID, otherUserID)
        try await db.collection(collection).document(docID).delete()
    }

    func fetchRelationships(for userID: String) async throws -> [Friendship] {
        let snapshot = try await db.collection(collection)
            .whereField("members", arrayContains: userID)
            .getDocuments()

        var results: [Friendship] = []
        for document in snapshot.documents {
            let data = document.data()
            guard let members = data["members"] as? [String],
                  let statusRaw = data["status"] as? String,
                  let status = Friendship.Status(rawValue: statusRaw),
                  let requesterID = data["requesterID"] as? String
            else { continue }

            let createdAt: Date
            if let ts = data["createdAt"] as? Timestamp {
                createdAt = ts.dateValue()
            } else {
                createdAt = Date()
            }

            results.append(Friendship(
                id: document.documentID,
                members: members,
                status: status,
                requesterID: requesterID,
                createdAt: createdAt
            ))
        }
        return results
    }
}
