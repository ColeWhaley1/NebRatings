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
    
    var body: some View {
        NavigationStack {
            List {
                appearanceSection
                accountSection
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
                    Text(user.name)
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
        }
    }
}

