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
        VStack(spacing: 0) {
            Spacer()
            
            // App branding/logo area
            VStack(spacing: 24) {
                Image(systemName: "moon.stars.fill")
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
            .padding(.bottom, 60)
            
            Spacer()
            
            // Authentication form
            VStack(spacing: 20) {
                if let errorMessage = errorMessage {
                    Text(errorMessage)
                        .font(.subheadline)
                        .foregroundStyle(.red)
                        .padding(.horizontal)
                        .multilineTextAlignment(.center)
                }
                
                VStack(spacing: 16) {
                    if showSignUp {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Username")
                                .font(.subheadline.bold())
                                .foregroundStyle(.primary)
                            TextField("Enter your username", text: $name)
                                .textFieldStyle(.roundedBorder)
                                .textContentType(.name)
                                .autocapitalization(.words)
                                .disabled(isSigningIn || isSigningUp)
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Email")
                            .font(.subheadline.bold())
                            .foregroundStyle(.primary)
                        TextField("Enter your email", text: $email)
                            .textFieldStyle(.roundedBorder)
                            .textContentType(.emailAddress)
                            .keyboardType(.emailAddress)
                            .autocapitalization(.none)
                            .disabled(isSigningIn || isSigningUp)
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Password")
                            .font(.subheadline.bold())
                            .foregroundStyle(.primary)
                        SecureField("Enter your password", text: $password)
                            .textFieldStyle(.roundedBorder)
                            .textContentType(showSignUp ? .newPassword : .password)
                            .disabled(isSigningIn || isSigningUp)
                    }
                    
                    if isSigningIn || isSigningUp {
                        ProgressView()
                            .padding(.top, 8)
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
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .disabled(isSigningIn || isSigningUp)
                    
                    // TEMPORARY: Quick login button for testing
                    Divider()
                        .padding(.vertical, 8)
                    
                    Button(action: quickLogin) {
                        Label("Quick Login (Testing)", systemImage: "bolt.fill")
                            .font(.subheadline.bold())
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .tint(.orange)
                    .controlSize(.large)
                    .disabled(isSigningIn || isSigningUp)
                }
                .padding(.horizontal, 40)
            }
            .padding(.bottom, 60)
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
        
        Task {
            do {
                let userID = try await store.authService.signIn(
                    email: email.trimmingCharacters(in: .whitespacesAndNewlines),
                    password: password
                )
                await store.signIn(userID: userID)
                isSigningIn = false
            } catch {
                errorMessage = "Sign in failed: \(error.localizedDescription)"
                isSigningIn = false
            }
        }
    }
    
    private func signUp() {
        guard isFormValid else { return }
        isSigningUp = true
        errorMessage = nil
        
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
                    if let nsError = error as NSError?, nsError.domain == "ProfileService" && nsError.code == -3 {
                        // Username already taken error
                        errorMessage = error.localizedDescription
                    } else {
                        errorMessage = "Account setup failed: \(error.localizedDescription). Please try again."
                    }
                    print("❌ Profile creation failed during sign-up: \(error.localizedDescription)")
                    
                    // Delete the Firebase Auth account since profile creation failed
                    do {
                        try await store.authService.deleteAccount()
                        print("✅ Deleted Firebase Auth account after profile creation failure")
                    } catch {
                        print("⚠️ Failed to delete Firebase Auth account after profile creation failure: \(error.localizedDescription)")
                        // Still try to sign out as fallback
                        try? await store.authService.signOut()
                    }
                    
                    isSigningUp = false
                    return
                }
                await store.signIn(userID: userID)
                isSigningUp = false
            } catch {
                errorMessage = "Sign up failed: \(error.localizedDescription)"
                isSigningUp = false
            }
        }
    }
    
    // TEMPORARY: Quick login function for testing
    private func quickLogin() {
        isSigningIn = true
        errorMessage = nil
        
        Task {
            do {
                let userID = try await store.authService.signIn(
                    email: "colewhaley1@gmail.com",
                    password: "nebratings"
                )
                await store.signIn(userID: userID)
                isSigningIn = false
            } catch {
                errorMessage = "Quick login failed: \(error.localizedDescription)"
                isSigningIn = false
            }
        }
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
