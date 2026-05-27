//
//  AvatarPickerView.swift
//  NebRatings
//

import SwiftUI

struct AvatarPickerView: View {
    @Environment(NebRatingsStore.self) private var store: NebRatingsStore
    @Environment(\.dismiss) private var dismiss

    @State private var selectedEmoji: String?
    @State private var isSaving = false
    @State private var errorMessage: String?

    private let columns = [GridItem(.adaptive(minimum: 80, maximum: 100), spacing: 16)]

    init() {
        _selectedEmoji = State(initialValue: nil)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    previewSection
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
            }
            .onAppear {
                selectedEmoji = store.currentUser?.avatarEmoji
            }
        }
    }

    private var hasChanges: Bool {
        selectedEmoji != store.currentUser?.avatarEmoji
    }

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

    private var presetGrid: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Pick a vibe")
                .font(.subheadline.bold())
                .foregroundStyle(.secondary)
                .padding(.horizontal, 4)

            LazyVGrid(columns: columns, spacing: 16) {
                // "None" tile to clear the avatar
                presetTile(emoji: nil)
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
        } label: {
            ZStack {
                Group {
                    if let emoji {
                        Circle().fill(Avatar.backgroundColor(for: emoji))
                        Text(emoji).font(.system(size: 36))
                    } else {
                        Circle().fill(Color.gray.opacity(0.2))
                        Image(systemName: "slash.circle")
                            .font(.system(size: 26))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .frame(width: 72, height: 72)
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

    private func save() {
        guard hasChanges else { return }
        isSaving = true
        errorMessage = nil
        Task {
            do {
                // Photo URL stays as-is for now; Step 5 will add upload support.
                try await store.updateAvatar(emoji: selectedEmoji, photoURL: store.currentUser?.avatarPhotoURL)
                isSaving = false
                dismiss()
            } catch {
                errorMessage = "Couldn't save avatar. Try again."
                isSaving = false
            }
        }
    }
}
