//
//  ContactFormView.swift
//  NebRatings
//
//  Created by Cole Whaley on 11/29/25.
//

import SwiftUI

struct ContactFormView: View {
    @Environment(NebRatingsStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    
    @State private var email = ""
    @State private var subject = ""
    @State private var message = ""
    @State private var isSubmitting = false
    @State private var errorMessage: String?
    @State private var showSuccessAlert = false
    
    private let contactEmail = "nebratings@gmail.com"
    private let helpText = "Have a question or feedback? Fill out the form below or email us directly."
    
    private var isFormValid: Bool {
        !email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        email.contains("@") &&
        !subject.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    var body: some View {
        Form {
            Section("Your Information") {
                TextField("Email", text: $email)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.emailAddress)
            }
            
            Section("Message") {
                Text(helpText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.bottom, 4)
                
                TextField("Subject", text: $subject)
                    .textInputAutocapitalization(.sentences)
                
                TextEditor(text: $message)
                    .frame(minHeight: 150)
                    .textSelection(.enabled)
            }
            
            Section {
                Button(action: submitForm) {
                    HStack {
                        if isSubmitting {
                            ProgressView()
                                .scaleEffect(0.8)
                        }
                        Text(isSubmitting ? "Submitting..." : "Submit")
                    }
                    .frame(maxWidth: .infinity)
                }
                .disabled(!isFormValid || isSubmitting)
            }
            
            Section {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Image(systemName: "envelope.fill")
                            .foregroundStyle(.blue)
                        Text("Email us directly:")
                            .foregroundStyle(.secondary)
                    }
                    Button(action: {
                        if let url = URL(string: "mailto:\(contactEmail)") {
                            UIApplication.shared.open(url)
                        }
                    }) {
                        Text(contactEmail)
                            .foregroundStyle(.blue)
                    }
                }
            }
        }
        .navigationTitle("Contact Us")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Success", isPresented: $showSuccessAlert) {
            Button("OK") {
                dismiss()
            }
        } message: {
            Text("Thank you for contacting us! We'll get back to you as soon as possible.")
        }
        .alert("Error", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK") {
                errorMessage = nil
            }
        } message: {
            if let error = errorMessage {
                Text(error)
            }
        }
    }
    
    private func submitForm() {
        guard isFormValid else { return }
        
        isSubmitting = true
        errorMessage = nil
        
        Task {
            do {
                let userID = store.authService.getCurrentUserID()
                let username = store.currentUser?.username
                let contactForm = ContactForm(
                    email: email.trimmingCharacters(in: .whitespacesAndNewlines),
                    subject: subject.trimmingCharacters(in: .whitespacesAndNewlines),
                    message: message.trimmingCharacters(in: .whitespacesAndNewlines),
                    userID: userID,
                    username: username
                )
                
                try await store.submitContactForm(contactForm)
                
                // Clear form
                email = ""
                subject = ""
                message = ""
                
                isSubmitting = false
                showSuccessAlert = true
            } catch {
                isSubmitting = false
                errorMessage = formatErrorMessage(error)
            }
        }
    }
    
    private func formatErrorMessage(_ error: Error) -> String {
        let errorString = error.localizedDescription.lowercased()
        
        // Network errors
        if errorString.contains("network") ||
           errorString.contains("connection") ||
           errorString.contains("internet") ||
           errorString.contains("offline") ||
           errorString.contains("timeout") {
            return "Connection problem. Please check your internet and try again."
        }
        
        // Permission errors
        if errorString.contains("permission") || errorString.contains("unauthorized") {
            return "Unable to submit form. Please try again."
        }
        
        // Default
        return "Unable to submit your message. Please try again or email us directly at \(contactEmail)."
    }
}

