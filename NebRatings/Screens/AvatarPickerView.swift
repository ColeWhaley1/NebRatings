//
//  AvatarPickerView.swift
//  NebRatings
//

import SwiftUI

struct AvatarPickerView: View {
    @Environment(NebRatingsStore.self) private var store: NebRatingsStore
    @Environment(\.dismiss) private var dismiss

    @State private var selectedEmoji: String?
    @State private var customEmojiField: String = ""
    @State private var isSaving = false
    @State private var errorMessage: String?
    @FocusState private var customFieldFocused: Bool

    private let columns = [GridItem(.adaptive(minimum: 64, maximum: 90), spacing: 14)]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    previewSection
                    customEmojiSection
                    presetGrid
                    if let errorMessage {
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Choose Avatar")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isSaving {
                        ProgressView()
                    } else {
                        Button("Save") { save() }
                            .fontWeight(.semibold)
                            .disabled(!hasChanges)
                    }
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { customFieldFocused = false }
                        .fontWeight(.semibold)
                }
            }
            .onAppear {
                selectedEmoji = store.currentUser?.avatarEmoji
            }
        }
    }

    // MARK: - Preview

    private var previewSection: some View {
        VStack(spacing: 10) {
            AvatarView(emoji: selectedEmoji, size: 120)
            Text(store.currentUser?.username ?? "")
                .font(.headline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
    }

    // MARK: - Custom emoji entry (Apple's emoji keyboard)

    private var customEmojiSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Type any emoji")
                .font(.subheadline.bold())
                .foregroundStyle(.secondary)

            HStack(spacing: 12) {
                TextField("😀", text: $customEmojiField)
                    .focused($customFieldFocused)
                    .font(.system(size: 32))
                    .multilineTextAlignment(.center)
                    .frame(width: 64, height: 56)
                    .background(Color(.tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
                    .onChange(of: customEmojiField) { _, newValue in
                        applyCustomEmoji(newValue)
                    }

                Text("Tap the field, then the emoji 😀 button to pick from thousands of emoji.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemGroupedBackground))
        )
    }

    // MARK: - Preset grid

    private var presetGrid: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Or pick a vibe")
                .font(.subheadline.bold())
                .foregroundStyle(.secondary)
                .padding(.horizontal, 4)

            LazyVGrid(columns: columns, spacing: 14) {
                presetTile(emoji: nil) // "None" / default
                ForEach(Avatar.presets, id: \.self) { emoji in
                    presetTile(emoji: emoji)
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemGroupedBackground))
        )
    }

    private func presetTile(emoji: String?) -> some View {
        let isSelected = emoji == selectedEmoji
        return Button {
            selectedEmoji = emoji
            customEmojiField = ""
            customFieldFocused = false
        } label: {
            ZStack {
                if let emoji {
                    Circle().fill(Avatar.backgroundColor(for: emoji))
                    Text(emoji).font(.system(size: 32))
                } else {
                    Circle().fill(Color.gray.opacity(0.2))
                    Image(systemName: "slash.circle")
                        .font(.system(size: 24))
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 64, height: 64)
            .overlay(
                Circle()
                    .stroke(isSelected ? Color.purple : Color.primary.opacity(0.08),
                            lineWidth: isSelected ? 3 : 1)
            )
            .scaleEffect(isSelected ? 1.05 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Logic

    private var hasChanges: Bool {
        selectedEmoji != store.currentUser?.avatarEmoji
    }

    /// Keep only the first emoji character a user enters in the custom field.
    private func applyCustomEmoji(_ text: String) {
        guard let firstEmoji = text.first(where: { $0.isEmojiCharacter }) else {
            // Non-emoji input: ignore and clear.
            if !text.isEmpty { customEmojiField = "" }
            return
        }
        let value = String(firstEmoji)
        selectedEmoji = value
        if customEmojiField != value { customEmojiField = value }
    }

    private func save() {
        guard hasChanges else { return }
        isSaving = true
        errorMessage = nil
        Task {
            do {
                // Avatars are emoji-only to keep the project on Firebase's free plan.
                try await store.updateAvatar(emoji: selectedEmoji)
                isSaving = false
                dismiss()
            } catch {
                errorMessage = "Couldn't save avatar. Try again."
                isSaving = false
            }
        }
    }
}
