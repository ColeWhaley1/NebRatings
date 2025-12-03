//
//  AuthService.swift
//  NebRatings
//
//  Created by Cole Whaley on 11/29/25.
//

import Foundation
import FirebaseAuth
import FirebaseCore

protocol AuthService {
    func signUp(email: String, password: String) async throws -> String // Returns user ID
    func signIn(email: String, password: String) async throws -> String // Returns user ID
    func signOut() async throws
    func getCurrentUserID() -> String?
    func getCurrentUser() -> User?
}

struct FirebaseAuthService: AuthService {
    func signUp(email: String, password: String) async throws -> String {
        guard FirebaseApp.app() != nil else {
            throw NSError(domain: "FirebaseAuth", code: -1, userInfo: [NSLocalizedDescriptionKey: "Firebase is not initialized"])
        }
        let result = try await Auth.auth().createUser(withEmail: email, password: password)
        return result.user.uid
    }
    
    func signIn(email: String, password: String) async throws -> String {
        guard FirebaseApp.app() != nil else {
            throw NSError(domain: "FirebaseAuth", code: -1, userInfo: [NSLocalizedDescriptionKey: "Firebase is not initialized"])
        }
        let result = try await Auth.auth().signIn(withEmail: email, password: password)
        return result.user.uid
    }
    
    func signOut() async throws {
        guard FirebaseApp.app() != nil else { return }
        try Auth.auth().signOut()
    }
    
    func getCurrentUserID() -> String? {
        guard FirebaseApp.app() != nil else { return nil }
        return Auth.auth().currentUser?.uid
    }
    
    func getCurrentUser() -> User? {
        guard FirebaseApp.app() != nil else { return nil }
        return Auth.auth().currentUser
    }
}

// Mock auth service for previews
struct MockAuthService: AuthService {
    func signUp(email: String, password: String) async throws -> String {
        // Simulate network delay
        try await Task.sleep(nanoseconds: 500_000_000)
        return "mock-user-\(UUID().uuidString)"
    }
    
    func signIn(email: String, password: String) async throws -> String {
        // Simulate network delay
        try await Task.sleep(nanoseconds: 500_000_000)
        return "mock-user-\(UUID().uuidString)"
    }
    
    func signOut() async throws {
        // Mock implementation - no-op
    }
    
    func getCurrentUserID() -> String? {
        return nil
    }
    
    func getCurrentUser() -> User? {
        return nil
    }
}


