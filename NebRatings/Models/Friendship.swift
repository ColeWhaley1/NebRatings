//
//  Friendship.swift
//  NebRatings
//

import Foundation

struct Friendship: Identifiable, Hashable {
    enum Status: String {
        case pending
        case accepted
    }

    /// Deterministic doc ID — sorted pair so (A,B) and (B,A) collide on the same document.
    let id: String
    let members: [String]
    let status: Status
    let requesterID: String
    let createdAt: Date

    static func documentID(_ uid1: String, _ uid2: String) -> String {
        [uid1, uid2].sorted().joined(separator: "_")
    }

    func otherUserID(currentUserID: String) -> String? {
        members.first { $0 != currentUserID }
    }

    func isIncomingRequest(for currentUserID: String) -> Bool {
        status == .pending && requesterID != currentUserID
    }

    func isOutgoingRequest(for currentUserID: String) -> Bool {
        status == .pending && requesterID == currentUserID
    }
}

enum RelationshipState: Equatable {
    case none
    case incomingRequest
    case outgoingRequest
    case friends
}
