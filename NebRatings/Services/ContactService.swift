//
//  ContactService.swift
//  NebRatings
//
//  Created by Cole Whaley on 11/29/25.
//

import Foundation
import FirebaseFirestore
import FirebaseAuth
import FirebaseCore

protocol ContactService {
    func submitContactForm(_ form: ContactForm) async throws
}

struct FirebaseContactService: ContactService {
    private var db: Firestore {
        // Return Firestore instance - errors will be handled at the call site if Firebase isn't initialized
        // This prevents app crashes and allows graceful error handling
        return Firestore.firestore()
    }
    
    func submitContactForm(_ form: ContactForm) async throws {
        var contactData: [String: Any] = [
            "email": form.email,
            "subject": form.subject,
            "message": form.message,
            "timestamp": Timestamp(date: form.timestamp),
            "userID": form.userID ?? NSNull()
        ]
        
        // Add username if available
        if let username = form.username {
            contactData["username"] = username
        }
        
        try await db.collection("feedback").document(form.id).setData(contactData)
    }
}

