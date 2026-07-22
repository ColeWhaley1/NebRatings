//
//  ContentPreferenceViews.swift
//  NebRatings
//
//  UI for choosing the recommendation maturity level: the one-time
//  onboarding prompt (shown when a profile has never chosen) and the
//  reusable option list embedded in Settings. Only recommendations are
//  affected — search and direct navigation stay open, and the footer says
//  so in both places.
//

import SwiftUI

/// One selectable option row: emoji, title, subtitle, checkmark.
struct ContentPreferenceOptionRow: View {
    let preference: ContentPreference
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 12) {
                Text(preference.emoji)
                    .font(.title2)
                VStack(alignment: .leading, spacing: 2) {
                    Text(preference.title)
                        .font(.body.weight(.medium))
                        .foregroundStyle(Color.primary)
                    Text(preference.subtitle)
                        .font(.caption)
                        .foregroundStyle(Color.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isSelected ? Color.purple : Color.secondary)
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
    }
}

/// The option list + save handling, shared by Settings and onboarding.
struct ContentPreferencePicker: View {
    @Environment(NebRatingsStore.self) private var store
    /// Called after a choice is successfully persisted.
    var onSaved: (() -> Void)? = nil

    @State private var saving: ContentPreference?

    var body: some View {
        ForEach(ContentPreference.allCases) { preference in
            ContentPreferenceOptionRow(
                preference: preference,
                // Checkmark only reflects an explicit choice — an unset
                // profile shows no selection even though General Audience
                // behavior applies by default.
                isSelected: store.currentUser?.contentPreference == preference
            ) {
                select(preference)
            }
            .disabled(saving != nil)
            .overlay(alignment: .trailing) {
                if saving == preference {
                    ProgressView()
                }
            }
        }
    }

    private func select(_ preference: ContentPreference) {
        saving = preference
        Task {
            try? await store.updateContentPreference(preference)
            saving = nil
            onSaved?()
        }
    }
}

/// One-time prompt shown after sign-in when the profile has no preference
/// yet. Dismissing without choosing keeps the General Audience default and
/// won't nag again this launch (Settings can change it anytime).
struct ContentPreferenceOnboardingSheet: View {
    @Environment(NebRatingsStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ContentPreferencePicker(onSaved: { dismiss() })
                } header: {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("What type of content would you like NebRatings to recommend?")
                            .font(.headline)
                            .foregroundStyle(Color.primary)
                            .textCase(nil)
                        Text("This shapes Discover and recommendations. You can always search for any title, and you can change this anytime in Settings.")
                            .font(.caption)
                            .foregroundStyle(Color.secondary)
                            .textCase(nil)
                    }
                    .padding(.bottom, 6)
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Content Preferences")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Later") { dismiss() }
                }
            }
            .tint(.purple)
        }
        .interactiveDismissDisabled(false)
    }
}
