//
//  SignInView.swift
//  NebRatings
//
//  Created by Cole Whaley on 11/29/25.
//

import SwiftUI
import FirebaseAuth

struct SignInView: View {
    @Environment(NebRatingsStore.self) private var store: NebRatingsStore
    @State private var email = ""
    @State private var password = ""
    @State private var name = ""
    @State private var isSigningIn = false
    @State private var isSigningUp = false
    @State private var errorMessage: String?
    @State private var showSignUp = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                Spacer()
                    .frame(height: 40)
                
                // App branding/logo area
                VStack(spacing: 24) {
                    Image(systemName: "chair.lounge.fill")
                        .font(.system(size: 80))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color.purple, Color.blue],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .shadow(color: .purple.opacity(0.5), radius: 20, x: 0, y: 10)
                    
                    VStack(spacing: 8) {
                        Text("NebRatings")
                            .font(.system(size: 36, weight: .bold, design: .default))
                            .foregroundStyle(.primary)
                        
                        Text("Drop your nebs on the best shows")
                            .font(.system(size: 16, weight: .regular, design: .default))
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                }
                .padding(.bottom, 20)
                
                // Authentication form
                VStack(spacing: 24) {
                    // Error message area with fixed minimum height
                    VStack(spacing: 0) {
                        if let errorMessage = errorMessage {
                            Text(errorMessage)
                                .font(.body)
                                .foregroundStyle(.red)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 12)
                                .multilineTextAlignment(.center)
                                .frame(minHeight: 60)
                        } else {
                            // Reserve space even when no error
                            Spacer()
                                .frame(height: 60)
                        }
                    }
                    
                    VStack(spacing: 24) {
                        if showSignUp {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Username")
                                    .font(.title3.bold())
                                    .foregroundStyle(.primary)
                                TextField("Enter your username", text: $name)
                                    .textContentType(.name)
                                    .autocapitalization(.words)
                                    .font(.title3)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 16)
                                    .background(Color(.systemBackground))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(Color.primary.opacity(0.3), lineWidth: 2)
                                    )
                                    .disabled(isSigningIn || isSigningUp)
                            }
                        }
                        
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Email")
                                .font(.title3.bold())
                                .foregroundStyle(.primary)
                            TextField("Enter your email", text: $email)
                                .textContentType(.emailAddress)
                                .keyboardType(.emailAddress)
                                .autocapitalization(.none)
                                .font(.title3)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 16)
                                .background(Color(.systemBackground))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.primary.opacity(0.3), lineWidth: 2)
                                )
                                .disabled(isSigningIn || isSigningUp)
                        }
                        
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Password")
                                .font(.title3.bold())
                                .foregroundStyle(.primary)
                            SecureField("Enter your password", text: $password)
                                .textContentType(showSignUp ? .newPassword : .password)
                                .font(.title3)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 16)
                                .background(Color(.systemBackground))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.primary.opacity(0.3), lineWidth: 2)
                                )
                                .disabled(isSigningIn || isSigningUp)
                        }
                        
                        if isSigningIn || isSigningUp {
                            ProgressView()
                                .padding(.top, 16)
                                .frame(height: 50)
                        } else {
                            Button(action: {
                                if showSignUp {
                                    signUp()
                                } else {
                                    signIn()
                                }
                            }) {
                                Text(showSignUp ? "Sign Up" : "Sign In")
                                    .font(.headline)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 50)
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.purple)
                            .controlSize(.large)
                            .disabled(!isFormValid)
                        }
                        
                        Button(action: {
                            showSignUp.toggle()
                            errorMessage = nil
                            if !showSignUp {
                                name = "" // Clear name when switching to sign in
                            }
                        }) {
                            Text(showSignUp ? "Already have an account? Sign In" : "Don't have an account? Sign Up")
                                .font(.body)
                                .foregroundStyle(.secondary)
                                .padding(.vertical, 8)
                        }
                        .disabled(isSigningIn || isSigningUp)
                    }
                    .padding(.horizontal, 32)
                }
                .padding(.bottom, 40)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
    }
    
    private var isFormValid: Bool {
        let emailValid = !email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
                        email.contains("@")
        let passwordValid = !password.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        
        if showSignUp {
            let nameValid = !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            return emailValid && passwordValid && nameValid
        } else {
            return emailValid && passwordValid
        }
    }
    
    private func signIn() {
        guard isFormValid else { return }
        isSigningIn = true
        errorMessage = nil
        
        // Clear the explicit sign out flag BEFORE calling authService.signIn()
        // This prevents the auth state listener from forcing a sign out during sign-in
        store.prepareForSignIn()
        
        Task {
            do {
                let userID = try await store.authService.signIn(
                    email: email.trimmingCharacters(in: .whitespacesAndNewlines),
                    password: password
                )
                await store.signIn(userID: userID)
                isSigningIn = false
            } catch {
                errorMessage = formatErrorMessage(error, isSignUp: false)
                isSigningIn = false
            }
        }
    }
    
    private func signUp() {
        guard isFormValid else { return }
        isSigningUp = true
        errorMessage = nil
        
        // Clear the explicit sign out flag BEFORE calling authService.signUp()
        // This prevents the auth state listener from interfering during sign-up
        store.prepareForSignIn()
        
        Task {
            do {
                let userID = try await store.authService.signUp(
                    email: email.trimmingCharacters(in: .whitespacesAndNewlines),
                    password: password
                )
                // Create profile with the entered name
                let userName = name.trimmingCharacters(in: .whitespacesAndNewlines)
                do {
                    try await store.createProfileIfNeeded(userID: userID, name: userName)
                } catch {
                    // If profile creation fails, delete the Firebase Auth account that was just created
                    // and show error to prevent sign-in
                    errorMessage = formatProfileCreationErrorMessage(error)
                    
                    // Delete the Firebase Auth account since profile creation failed
                    do {
                        try await store.authService.deleteAccount()
                    } catch {
                        // Failed to delete Firebase Auth account after profile creation failure
                        // Still try to sign out as fallback
                        try? await store.authService.signOut()
                    }
                    
                    isSigningUp = false
                    return
                }
                await store.signIn(userID: userID)
                isSigningUp = false
            } catch {
                errorMessage = formatErrorMessage(error, isSignUp: true)
                isSigningUp = false
            }
        }
    }
    
    
    private func formatErrorMessage(_ error: Error, isSignUp: Bool) -> String {
        let errorString = error.localizedDescription.lowercased()
        
        // Email format errors (safe to be specific)
        if errorString.contains("email") && (errorString.contains("badly formatted") || errorString.contains("invalid") || errorString.contains("malformed")) {
            return "Please enter a valid email address"
        }
        
        // Sign-up specific errors (can be more specific)
        if isSignUp {
            if errorString.contains("email") && errorString.contains("already in use") {
                return "This email is already registered. Try signing in instead"
            }
            if errorString.contains("password") && (errorString.contains("too weak") || errorString.contains("too short") || errorString.contains("minimum")) {
                return "Password is too weak. Please use at least 6 characters"
            }
            if errorString.contains("password") && errorString.contains("invalid") {
                return "Password must be at least 6 characters long"
            }
        }
        
        // Sign-in errors (must be generic for security - don't reveal if email exists)
        if !isSignUp {
            // For sign-in, always use generic message to avoid revealing if email exists
            // Catch all password-related errors
            if errorString.contains("user record") || 
               errorString.contains("user not found") ||
               errorString.contains("email") && errorString.contains("not found") ||
               errorString.contains("password") ||
               errorString.contains("wrong password") ||
               errorString.contains("invalid credential") ||
               errorString.contains("credential") ||
               errorString.contains("authentication") {
                return "Email or password is incorrect"
            }
        }
        
        // Network errors (safe to be specific)
        if errorString.contains("network") || 
           errorString.contains("connection") || 
           errorString.contains("internet") ||
           errorString.contains("offline") ||
           errorString.contains("timeout") {
            return "Connection problem. Please check your internet and try again"
        }
        
        // Rate limiting (safe to be specific)
        if errorString.contains("too many requests") || 
           errorString.contains("too many attempts") ||
           errorString.contains("quota") ||
           errorString.contains("rate limit") {
            return "Too many attempts. Please wait a moment and try again"
        }
        
        // Permission/access errors
        if errorString.contains("permission") || errorString.contains("unauthorized") || errorString.contains("access denied") {
            return "You don't have permission to do this. Please contact support if this continues"
        }
        
        // Account disabled/disabled errors
        if errorString.contains("disabled") || errorString.contains("suspended") || errorString.contains("banned") {
            return "This account has been disabled. Please contact support for help"
        }
        
        // Token/session errors
        if errorString.contains("token") || errorString.contains("session") || errorString.contains("expired") {
            return "Your session expired. Please try again"
        }
        
        // Firebase specific errors
        if errorString.contains("firebase") {
            if errorString.contains("auth") {
                return "Authentication error. Please try again"
            }
            return "Service error. Please try again in a moment"
        }
        
        // API/service errors
        if errorString.contains("api") || errorString.contains("service") || errorString.contains("server") {
            return "Service temporarily unavailable. Please try again in a moment"
        }
        
        // Validation errors
        if errorString.contains("validation") || errorString.contains("invalid") {
            if isSignUp {
                return "Please check that all fields are filled correctly"
            } else {
                return "Please check your email and password"
            }
        }
        
        // Default fallback - try to extract meaningful info from error
        let originalError = error.localizedDescription
        if !originalError.isEmpty && originalError.count < 100 {
            // If error message is short and readable, show it
            return originalError
        }
        
        return "Unable to sign in. Please check your information and try again"
    }
    
    private func formatProfileCreationErrorMessage(_ error: Error) -> String {
        let errorString = error.localizedDescription.lowercased()
        
        // Username already taken
        if errorString.contains("username") && (errorString.contains("already taken") || errorString.contains("already exists") || errorString.contains("taken")) {
            return "This username is already taken. Please choose a different one."
        }
        
        // Empty name
        if errorString.contains("name") && (errorString.contains("empty") || errorString.contains("cannot be empty") || errorString.contains("required")) {
            return "Please enter a username"
        }
        
        // Invalid name format
        if errorString.contains("invalid") && errorString.contains("name") {
            return "Username contains invalid characters. Please use only letters, numbers, and spaces."
        }
        
        // Network errors
        if errorString.contains("network") || 
           errorString.contains("connection") || 
           errorString.contains("internet") ||
           errorString.contains("offline") ||
           errorString.contains("timeout") {
            return "Connection problem. Please check your internet and try again"
        }
        
        // Permission errors
        if errorString.contains("permission") || errorString.contains("unauthorized") {
            return "Unable to create account. Please try again"
        }
        
        // Default fallback
        return "Unable to create account. Please try again"
    }
}

#Preview {
    let store = NebRatingsStore(
        catalogService: TMDBService(),
        reviewService: FirebaseReviewService(),
        profileService: FirebaseProfileService(),
        authService: MockAuthService()
    )
    return SignInView()
        .environment(store)
}
