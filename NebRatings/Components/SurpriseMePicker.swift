//
//  SurpriseMePicker.swift
//  NebRatings
//
//  "Surprise Me" — slot-machine picker for a list. Spins through the list's
//  posters with a decelerating tick, lands on a random title, then reveals it
//  with a spring pop. The caller supplies resolved Shows and handles opening
//  the winner's detail page after the sheet dismisses.
//

import SwiftUI
import UIKit  // haptics

struct SurpriseMePicker: View {
    /// Shows to pick from — the list's (filtered) contents, already resolved
    /// from the show cache. Must be non-empty.
    let candidates: [Show]
    /// Called when the user opens the winning pick. The sheet dismisses
    /// itself first; the caller navigates on dismiss.
    let onOpen: (Show) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var displayedIndex = 0
    @State private var isSpinning = false
    @State private var revealed = false
    @State private var spinTask: Task<Void, Never>?

    private var displayedShow: Show? {
        guard !candidates.isEmpty else { return nil }
        return candidates[displayedIndex % candidates.count]
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()

                if let show = displayedShow {
                    posterCard(for: show)

                    VStack(spacing: 6) {
                        Text(show.title)
                            .font(revealed ? .title2.bold() : .headline)
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                            // Fixed two-line block so the card doesn't hop
                            // vertically as titles of different lengths cycle.
                            .frame(height: 60)

                        HStack(spacing: 8) {
                            Text(show.category.rawValue.uppercased())
                                .font(.caption.bold())
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(show.category.badgeColor.opacity(0.15), in: Capsule())
                                .foregroundStyle(show.category.badgeColor)
                            Text(String(show.year))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .opacity(revealed ? 1 : 0)
                    }
                }

                Spacer()

                actionButtons
            }
            .padding(24)
            .navigationTitle("Surprise Me")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .task {
                // Auto-spin on open — the fun starts immediately.
                startSpin()
            }
            .onDisappear {
                spinTask?.cancel()
            }
        }
    }

    // MARK: - Pieces

    private func posterCard(for show: Show) -> some View {
        ZStack {
            if let posterURL = show.posterURL {
                AsyncImageView(urlString: posterURL)
            } else {
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.gray.opacity(0.2))
                    .overlay(
                        Image(systemName: show.category == .movie ? "film" : "tv")
                            .font(.system(size: 44))
                            .foregroundStyle(.secondary)
                    )
            }
        }
        .frame(width: 220, height: 330)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(revealed ? 0.35 : 0.15), radius: revealed ? 18 : 8, y: 8)
        // The reveal pop: winner scales up with a bouncy spring; during the
        // spin the card stays slightly shrunk so the pop reads as an event.
        .scaleEffect(revealed ? 1.0 : 0.88)
        .animation(.spring(response: 0.45, dampingFraction: 0.6), value: revealed)
        // Card id changes every tick → crossfade between posters.
        .id(displayedIndex % max(candidates.count, 1))
        .transition(.opacity)
    }

    @ViewBuilder
    private var actionButtons: some View {
        if revealed, let show = displayedShow {
            VStack(spacing: 12) {
                Button {
                    dismiss()
                    onOpen(show)
                } label: {
                    Label("Take Me There", systemImage: "arrow.right.circle.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.borderedProminent)
                .tint(.purple)

                Button {
                    startSpin()
                } label: {
                    Label("Spin Again", systemImage: "arrow.triangle.2.circlepath")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
        } else {
            // Placeholder keeps the layout stable while spinning.
            VStack(spacing: 12) {
                Button {} label: {
                    Label("Take Me There", systemImage: "arrow.right.circle.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.borderedProminent)
                Button {} label: {
                    Label("Spin Again", systemImage: "arrow.triangle.2.circlepath")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
            .opacity(0)
            .disabled(true)
        }
    }

    // MARK: - Spin engine

    private func startSpin() {
        guard !candidates.isEmpty, !isSpinning else { return }
        spinTask?.cancel()

        // Single candidate: nothing to spin through — reveal immediately.
        guard candidates.count > 1 else {
            revealed = true
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            return
        }

        isSpinning = true
        revealed = false

        // Land on a uniformly random winner: fix the winner index up front,
        // then take enough one-step ticks (a couple of full loops + offset)
        // to stop exactly there.
        let count = candidates.count
        let winnerIndex = Int.random(in: 0..<count)
        let baseTicks = max(18, 2 * count)
        let start = displayedIndex % count
        let offset = positiveMod(winnerIndex - (start + baseTicks), count)
        let totalTicks = baseTicks + offset

        spinTask = Task {
            let tickHaptic = UIImpactFeedbackGenerator(style: .light)
            tickHaptic.prepare()

            for tick in 0..<totalTicks {
                guard !Task.isCancelled else { return }
                // Ease-out: delays grow from ~45ms to ~350ms toward the end,
                // so the reel visibly decelerates before landing.
                let progress = Double(tick) / Double(totalTicks)
                let delay = 0.045 + 0.305 * progress * progress
                try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                guard !Task.isCancelled else { return }

                withAnimation(.easeInOut(duration: 0.1)) {
                    displayedIndex += 1
                }
                tickHaptic.impactOccurred(intensity: 0.6 + 0.4 * progress)
            }

            guard !Task.isCancelled else { return }
            isSpinning = false
            revealed = true
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }
    }

    /// True mathematical modulo (Swift's % can return negatives).
    private func positiveMod(_ a: Int, _ n: Int) -> Int {
        ((a % n) % n + n) % n
    }
}

// MARK: - Preview

#Preview {
    SurpriseMePicker(
        candidates: Array(Show.previewData.prefix(5)),
        onOpen: { _ in }
    )
}
