//
//  ModerationService.swift
//  NebRatings
//
//  Records user reports and blocks so the developer is notified of
//  objectionable content and abusive users — required by App Store Review
//  Guideline 1.2. Reports and blocks are written to Firestore collections
//  (`reports`, `blocks`) that the developer monitors and acts on within 24
//  hours (removing content and ejecting offending users).
//

import Foundation
import FirebaseFirestore

protocol ModerationService {
    /// Files a report against a specific review.
    func reportReview(reviewID: String,
                      authorID: String?,
                      authorName: String,
                      reporterID: String,
                      reason: String) async throws

    /// Records that `blockerID` blocked `blockedID`, and files an
    /// accompanying report so the developer is notified of the abusive user.
    func blockUser(blockerID: String,
                   blockedID: String,
                   blockedName: String,
                   reason: String?) async throws
}

struct FirebaseModerationService: ModerationService {
    private var db: Firestore { Firestore.firestore() }

    func reportReview(reviewID: String,
                      authorID: String?,
                      authorName: String,
                      reporterID: String,
                      reason: String) async throws {
        try await db.collection("reports").addDocument(data: [
            "type": "review",
            "reviewID": reviewID,
            "authorID": authorID ?? "",
            "authorName": authorName,
            "reporterID": reporterID,
            "reason": reason,
            "status": "open",
            "createdAt": Timestamp(date: Date())
        ])
    }

    func blockUser(blockerID: String,
                   blockedID: String,
                   blockedName: String,
                   reason: String?) async throws {
        // A deterministic doc id keeps repeated blocks idempotent.
        try await db.collection("blocks").document("\(blockerID)_\(blockedID)").setData([
            "blockerID": blockerID,
            "blockedID": blockedID,
            "blockedName": blockedName,
            "createdAt": Timestamp(date: Date())
        ])
        // File a report too so blocking surfaces the abusive user for review.
        try await db.collection("reports").addDocument(data: [
            "type": "block",
            "authorID": blockedID,
            "authorName": blockedName,
            "reporterID": blockerID,
            "reason": reason ?? "User blocked",
            "status": "open",
            "createdAt": Timestamp(date: Date())
        ])
    }
}

/// No-op moderation service for previews/tests.
struct MockModerationService: ModerationService {
    func reportReview(reviewID: String, authorID: String?, authorName: String, reporterID: String, reason: String) async throws {}
    func blockUser(blockerID: String, blockedID: String, blockedName: String, reason: String?) async throws {}
}
