//
//  SettingsView.swift
//  NebRatings
//
//  Created by Cole Whaley on 11/29/25.
//

import SwiftUI

struct SettingsView: View {
    @Environment(NebRatingsStore.self) private var store: NebRatingsStore
    @AppStorage("colorScheme") private var colorScheme: String = "system"
    @Environment(\.dismiss) private var dismiss
    @State private var showingDeleteConfirmation = false
    @State private var isDeletingAccount = false
    @State private var deleteError: String?
    
    var body: some View {
        NavigationStack {
            List {
                appearanceSection
                accountSection
                contactSection
                legalSection
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
        }
    }
    
    private var appearanceSection: some View {
        Section("Appearance") {
            Picker("Theme", selection: $colorScheme) {
                Label("System", systemImage: "circle.lefthalf.filled")
                    .tag("system")
                Label("Light", systemImage: "sun.max.fill")
                    .tag("light")
                Label("Dark", systemImage: "moon.fill")
                    .tag("dark")
            }
            .pickerStyle(.menu)
        }
    }
    
    private var accountSection: some View {
        Section("Account") {
            if let user = store.currentUser {
                HStack {
                    Text("Signed in as")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(user.username)
                        .fontWeight(.medium)
                }
            }
            
            Button(role: .destructive, action: {
                Task {
                    await store.signOut()
                    dismiss()
                }
            }) {
                Label("Sign Out", systemImage: "arrow.right.square")
            }
            
            Button(role: .destructive, action: {
                showingDeleteConfirmation = true
            }) {
                HStack {
                    if isDeletingAccount {
                        ProgressView()
                            .scaleEffect(0.8)
                    }
                    Label("Delete Account", systemImage: "trash")
                }
            }
            .disabled(isDeletingAccount)
        }
        .alert("Delete Account", isPresented: $showingDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                Task {
                    await deleteAccount()
                }
            }
        } message: {
            Text("Are you sure you want to delete your account? This will permanently delete your profile, all your reviews, and all lists you own. This action cannot be undone.")
        }
        .alert("Error", isPresented: Binding(
            get: { deleteError != nil },
            set: { if !$0 { deleteError = nil } }
        )) {
            Button("OK") {
                deleteError = nil
            }
        } message: {
            if let error = deleteError {
                Text(error)
            }
        }
    }
    
    private func deleteAccount() async {
        isDeletingAccount = true
        deleteError = nil
        
        do {
            try await store.deleteAccount()
            dismiss()
        } catch {
            deleteError = formatDeleteErrorMessage(error)
        }
        
        isDeletingAccount = false
    }
    
    private func formatDeleteErrorMessage(_ error: Error) -> String {
        if let nsError = error as NSError? {
            switch nsError.domain {
            case "NebRatingsStore":
                return "Unable to delete account. Please try again."
            case "FirebaseReviewService":
                return "Failed to delete reviews. Please try again."
            case "FirebaseListService":
                return "Failed to delete lists. Please try again."
            case "ProfileService":
                return "Failed to delete profile. Please try again."
            case "FirebaseAuth":
                if nsError.code == -2 {
                    return "No authenticated user found."
                }
                return "Failed to delete authentication account. Please try again."
            default:
                return "An error occurred while deleting your account. Please try again."
            }
        }
        return "An error occurred while deleting your account. Please try again."
    }
    
    private var contactSection: some View {
        Section("Support") {
            NavigationLink(destination: ContactFormView()) {
                Label("Contact Us", systemImage: "envelope")
            }
        }
    }
    
    private var legalSection: some View {
        Section("Legal") {
            NavigationLink(destination: PrivacyPolicyView()) {
                Label("Privacy Policy", systemImage: "hand.raised.fill")
            }
            
            NavigationLink(destination: TermsAndConditionsView()) {
                Label("Terms and Conditions", systemImage: "doc.text.fill")
            }
        }
    }
}

