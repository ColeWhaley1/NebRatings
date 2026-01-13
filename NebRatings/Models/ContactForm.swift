//
//  ContactForm.swift
//  NebRatings
//
//  Created by Cole Whaley on 11/29/25.
//

import Foundation

struct ContactForm: Identifiable {
    let id: String
    let email: String
    let subject: String
    let message: String
    let timestamp: Date
    let userID: String? // Optional - user might not be logged in
    let username: String? // Optional - username if user is logged in
    
    init(id: String = UUID().uuidString,
         email: String,
         subject: String,
         message: String,
         timestamp: Date = .now,
         userID: String? = nil,
         username: String? = nil) {
        self.id = id
        self.email = email
        self.subject = subject
        self.message = message
        self.timestamp = timestamp
        self.userID = userID
        self.username = username
    }
}

