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
    @State private var showingChangePassword = false
    @State private var isCheckingUpdate = false
    @State private var updateCheckMessage: String?
    @State private var updateCheckOffersUpdate = false
    @State private var showingUpdateCheckResult = false

    var body: some View {
        NavigationStack {
            List {
                appearanceSection
                contentPreferencesSection
                accountSection
                safetySection
                contactSection
                legalSection
                aboutSection
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
            .alert("Check for Updates", isPresented: $showingUpdateCheckResult) {
                if updateCheckOffersUpdate {
                    Button("Update") { AppStoreReviewHelper.openAppStorePage() }
                    Button("Not Now", role: .cancel) {}
                } else {
                    Button("OK", role: .cancel) {}
                }
            } message: {
                Text(updateCheckMessage ?? "")
            }
        }
    }

    private var aboutSection: some View {
        Section {
            HStack {
                Text("Version")
                Spacer()
                Text(store.currentAppVersion)
                    .foregroundStyle(.secondary)
            }
            Button {
                Task {
                    isCheckingUpdate = true
                    let result = await store.manualUpdateCheck()
                    isCheckingUpdate = false
                    applyUpdateCheckResult(result)
                }
            } label: {
                HStack {
                    Label("Check for Updates", systemImage: "arrow.triangle.2.circlepath")
                    if isCheckingUpdate {
                        Spacer()
                        ProgressView().scaleEffect(0.8)
                    }
                }
            }
            .disabled(isCheckingUpdate)
        } header: {
            Text("About")
        }
    }

    private func applyUpdateCheckResult(_ result: NebRatingsStore.UpdateCheckResult) {
        switch result {
        case let .updateAvailable(current, latest):
            updateCheckMessage = "A new version (\(latest)) is available. You're on \(current)."
            updateCheckOffersUpdate = true
        case let .upToDate(current, latest):
            updateCheckMessage = "You're up to date. (Version \(current); latest published is \(latest).)"
            updateCheckOffersUpdate = false
        case let .notConfigured(current):
            updateCheckMessage = "You're on version \(current). No latest version is set on the server yet — add a document 'version' in the 'appConfig' collection with a string field 'latestVersion'."
            updateCheckOffersUpdate = false
        case let .failed(current, message):
            updateCheckMessage = "Couldn't check for updates (you're on \(current)): \(message)"
            updateCheckOffersUpdate = false
        }
        showingUpdateCheckResult = true
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
    
    private var contentPreferencesSection: some View {
        Section {
            ContentPreferencePicker()
        } header: {
            Text("Content Preferences")
        } footer: {
            Text("Shapes what Discover and recommendations suggest. Search always shows every title.")
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
            
            Button(action: { showingChangePassword = true }) {
                Label("Change Password", systemImage: "key.fill")
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
        .sheet(isPresented: $showingChangePassword) {
            ChangePasswordSheet(onDismiss: { showingChangePassword = false })
                .environment(store)
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
}

// MARK: - Change Password Sheet
private struct ChangePasswordSheet: View {
    let onDismiss: () -> Void
    @Environment(NebRatingsStore.self) private var store: NebRatingsStore
    
    @State private var currentPassword = ""
    @State private var newPassword = ""
    @State private var confirmPassword = ""
    @State private var isUpdating = false
    @State private var errorMessage: String?
    @State private var didSucceed = false
    
    var body: some View {
        NavigationStack {
            Group {
                if didSucceed {
                    VStack(spacing: 24) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 60))
                            .foregroundStyle(.green)
                        Text("Password updated")
                            .font(.title2.bold())
                        Text("Your password has been changed successfully.")
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    Form {
                        Section {
                            SecureField("Current password", text: $currentPassword)
                                .textContentType(.password)
                                .disabled(isUpdating)
                            SecureField("New password", text: $newPassword)
                                .textContentType(.newPassword)
                                .disabled(isUpdating)
                            SecureField("Confirm new password", text: $confirmPassword)
                                .textContentType(.newPassword)
                                .disabled(isUpdating)
                        } header: {
                            Text("Password")
                        } footer: {
                            Text("Use at least 6 characters for your new password.")
                        }
                        
                        if let errorMessage {
                            Section {
                                Text(errorMessage)
                                    .foregroundStyle(.red)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Change Password")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        onDismiss()
                    }
                }
                if !didSucceed {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Update") {
                            updatePassword()
                        }
                        .disabled(isUpdating || !isFormValid)
                    }
                } else {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") {
                            onDismiss()
                        }
                    }
                }
            }
        }
    }
    
    private var isFormValid: Bool {
        !currentPassword.isEmpty &&
        !newPassword.trimmingCharacters(in: .whitespaces).isEmpty &&
        newPassword.count >= 6 &&
        newPassword == confirmPassword
    }
    
    private func updatePassword() {
        guard isFormValid else { return }
        isUpdating = true
        errorMessage = nil
        
        Task {
            do {
                try await store.authService.updatePassword(
                    currentPassword: currentPassword,
                    newPassword: newPassword
                )
                await MainActor.run {
                    didSucceed = true
                }
            } catch {
                await MainActor.run {
                    errorMessage = formatChangePasswordError(error)
                }
            }
            await MainActor.run {
                isUpdating = false
            }
        }
    }
    
    private func formatChangePasswordError(_ error: Error) -> String {
        let errorString = error.localizedDescription.lowercased()
        if errorString.contains("wrong password") ||
           errorString.contains("invalid credential") ||
           errorString.contains("recent login") ||
           errorString.contains("requires recent login") {
            return "Current password is incorrect. Please try again."
        }
        if errorString.contains("too weak") || errorString.contains("too short") || errorString.contains("minimum") {
            return "New password must be at least 6 characters."
        }
        if errorString.contains("network") || errorString.contains("connection") || errorString.contains("internet") {
            return "Connection problem. Please check your internet and try again."
        }
        if errorString.contains("too many") || errorString.contains("rate limit") {
            return "Too many attempts. Please wait a moment and try again."
        }
        return "Unable to update password. Please try again."
    }
}

extension SettingsView {
    private var contactSection: some View {
        Section("Support") {
            Button(action: { AppStoreReviewHelper.openAppStoreReviewPage() }) {
                Label("Rate NebRatings", systemImage: "star.fill")
            }
            
            NavigationLink(destination: ContactFormView()) {
                Label("Contact Us", systemImage: "envelope")
            }
        }
    }
    
    private var safetySection: some View {
        Section {
            NavigationLink(destination: BlockedUsersView()) {
                HStack {
                    Label("Blocked Users", systemImage: "hand.raised")
                    Spacer()
                    if !store.blockedUserIDs.isEmpty {
                        Text("\(store.blockedUserIDs.count)")
                            .foregroundStyle(.secondary)
                    }
                }
            }
        } header: {
            Text("Privacy & Safety")
        } footer: {
            Text("Review and manage users you've blocked.")
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

