//
//  ReactionsBar.swift
//  NebRatings
//
//  Bottom-of-card reactions strip. Renders one pill per emoji variant —
//  sorted by count descending — with a "+" picker button on the right.
//  Horizontal `ScrollView` handles overflow when there are more variants
//  than fit, so every reaction stays reachable without a "+N more" disclosure.
//

import SwiftUI

struct ReactionsBar: View {
    /// Map of userID → emoji.
    let reactions: [String: String]
    /// Used to highlight the pill the current user reacted with, if any.
    let currentUserID: String?
    /// When non-nil, pills are tappable (toggles my reaction to that emoji,
    /// or clears it if I had already reacted with that one) and the picker
    /// button is shown. When nil, the bar is read-only.
    let onReact: ((String?) -> Void)?

    /// Controls focus on the hidden emoji-capture field. Tapping the picker
    /// button calls `pickerController.focus()`, which calls
    /// `becomeFirstResponder()` directly — no @Binding propagation latency
    /// or skipped SwiftUI updates, so the keyboard appears on the first tap
    /// every time. `@StateObject` so the same controller instance persists
    /// across re-renders of the ReactionsBar.
    @StateObject private var pickerController = EmojiPickerController()

    /// Flips `true` shortly after the bar first appears. Gates the per-pill
    /// entrance animation so that pills already present when a card loads
    /// (or scrolls into view) appear instantly, while pills *added later by
    /// the user* animate in. Without this gate every reaction would pop on
    /// every navigation into the tab/card.
    @State private var isReady = false

    private var sortedReactions: [(emoji: String, count: Int)] {
        // (emoji, count) sorted by count descending. Stable secondary sort
        // by the emoji string itself keeps ordering deterministic when
        // counts tie.
        var counts: [String: Int] = [:]
        for emoji in reactions.values {
            counts[emoji, default: 0] += 1
        }
        return counts
            .map { (emoji: $0.key, count: $0.value) }
            .sorted { lhs, rhs in
                if lhs.count != rhs.count { return lhs.count > rhs.count }
                return lhs.emoji < rhs.emoji
            }
    }

    private var myReaction: String? {
        guard let currentUserID else { return nil }
        return reactions[currentUserID]
    }

    var body: some View {
        HStack(spacing: 6) {
            // Scrollable strip of reaction pills. ScrollView handles overflow
            // by allowing the user to swipe horizontally; no pills are hidden.
            //
            // It's ALWAYS rendered — even with zero pills — for two reasons:
            //   1. The bar reserves a constant height (see the outer .frame
            //      below), so adding the first reaction never reflows the card.
            //   2. The animation scope stays mounted, so the *first* pill added
            //      actually transitions in instead of appearing fully-formed
            //      alongside a freshly-created container.
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(sortedReactions, id: \.emoji) { item in
                        ReactionPill(
                            emoji: item.emoji,
                            count: item.count,
                            isMine: item.emoji == myReaction,
                            isInteractive: onReact != nil,
                            // Only animate the entrance for pills that appear
                            // *after* the bar is on screen — i.e. genuine new
                            // reactions, not the ones present at load time.
                            animateEntrance: isReady
                        ) {
                            guard let onReact else { return }
                            // Tap behavior:
                            //   - If I already reacted with this emoji → clear my reaction
                            //   - Otherwise → set my reaction to this emoji (replaces any previous)
                            if myReaction == item.emoji {
                                onReact(nil)
                            } else {
                                onReact(item.emoji)
                            }
                        }
                        // INSERTION is handled by the pill's own on-appear
                        // keyframe SLAM (see ReactionPill) — NOT by this
                        // transition. SwiftUI's insertion transitions are
                        // unreliable here: the keyboard teardown after picking an
                        // emoji (resignFirstResponder) and List row hosting both
                        // swallowed the insert, so adds never animated. An
                        // appear-driven keyframe animation fires on mount
                        // regardless of container or keyboard. We keep a REMOVAL
                        // transition only — removals are reliable and are driven
                        // by the `withAnimation` transaction in setReaction.
                        .transition(.asymmetric(
                            insertion: .identity,
                            removal: .scale(scale: 0.85).combined(with: .opacity)
                        ))
                    }
                }
                // Breathing room INSIDE the scroll content so the entrance
                // SLAM isn't clipped by the ScrollView. The new pill punches
                // past full size to ~1.2× at the peak of its keyframe slam
                // (see ReactionPill); without this inset the leading/trailing
                // pill's edge would push past the scroll clip bounds and get
                // shaved mid-slam. 8pt each side absorbs the ~6–7pt of overshoot
                // a wide pill grows by, with margin to spare.
                // (Empty bar = empty HStack, so this padding is invisible when
                // there are no reactions — the card still looks natural.)
                .padding(.horizontal, 8)
                .frame(maxHeight: .infinity) // center pills vertically in the fixed-height bar
                // NOTE: no scoped `.animation(value: reactions)` here. The pill
                // insert/remove transitions (and the count's numericText roll)
                // are driven by the explicit `withAnimation` transaction that
                // wraps the reaction mutation in `NebRatingsStore.setReaction`.
                // A scoped animation here was unreliable: it was swallowed by
                // the `List` rows in the show-detail carousel and didn't fire
                // for keyboard-driven insertions. The explicit transaction
                // reaches every container, so add + remove animate everywhere.
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Picker button — only shown when the user can react.
            if onReact != nil {
                Button {
                    pickerController.focus()
                } label: {
                    Image(systemName: "face.smiling")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                        .frame(width: 32, height: 28)
                        // Material gives a frosted glass effect that contrasts
                        // cleanly on both light and dark — and crucially on
                        // the purple-tinted own-review card.
                        .background(.regularMaterial, in: Capsule())
                        .overlay(
                            Capsule().strokeBorder(Color(uiColor: .separator), lineWidth: 0.75)
                        )
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Add reaction")
                // Hidden 1×1pt capture field sits inside the button frame
                // (via .background, so it doesn't affect layout). It hands
                // its underlying UITextField to `pickerController` in
                // makeUIView; the button tap then directly calls
                // `pickerController.focus()` to summon the keyboard.
                .background(
                    EmojiCaptureField(controller: pickerController) { emoji in
                        onReact?(emoji)
                    }
                    .frame(width: 1, height: 1)
                    .opacity(0.01)
                    .allowsHitTesting(false)
                )
            }
        }
        // Constant height whether the bar is empty, has one pill, or many —
        // so reactions appearing/disappearing never shift the rest of the card.
        .frame(height: Self.barHeight)
        .frame(maxWidth: .infinity, alignment: .leading)
        // Runs once after the bar appears (after the initial pills' own
        // `.onAppear` have already fired with `isReady == false`, so they
        // don't pop). From here on, any newly-added pill mounts with
        // `animateEntrance == true` and springs in.
        .task { isReady = true }
    }

    /// Fixed height of the reactions strip. Comfortably fits a pill (~29pt) and
    /// the picker button (28pt) with a little vertical breathing room so the
    /// "mine" pill outline isn't clipped.
    private static let barHeight: CGFloat = 34
}

// MARK: - Pill

private struct ReactionPill: View {
    let emoji: String
    let count: Int
    let isMine: Bool
    let isInteractive: Bool
    /// When true, the pill slams in on mount (a brand-new reaction). When
    /// false (pills already present at bar load), it just appears at full size.
    let animateEntrance: Bool
    let onTap: () -> Void

    /// Flipped `true` in `.onAppear` for a slamming pill so the
    /// `.sensoryFeedback` below fires a single impact haptic in sync with the
    /// visual slam. Stays `false` for pre-existing pills, so they don't buzz on
    /// every scroll-into-view. Device-only — the Simulator has no taptic engine.
    @State private var landed = false

    var body: some View {
        Button {
            onTap()
        } label: {
            HStack(spacing: 4) {
                Text(emoji)
                    .font(.callout)
                Text("\(count)")
                    .font(.caption.bold())
                    .foregroundStyle(isMine ? Color.purple : .primary)
                    .monospacedDigit()
                    // When a shared emoji's count ticks up/down, roll the
                    // number instead of hard-cutting it.
                    .contentTransition(.numericText(value: Double(count)))
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 4)
            // Material gives us frosted-glass contrast on any card variant —
            // including the purple-tinted own-review card — without us having
            // to pick per-mode colors. The *mine* state is signaled by the
            // purple count text + a stronger purple-tinted outline rather
            // than by a loud solid fill, which was overpowering visually.
            .background(.regularMaterial, in: Capsule())
            .overlay(
                // strokeBorder (not stroke) so the outline is drawn *inside*
                // the pill bounds — a centered stroke spills half its width
                // past the frame and gets clipped by the surrounding ScrollView,
                // which is what cut off the top/bottom of the pill outline.
                Capsule()
                    .strokeBorder(pillStroke, lineWidth: isMine ? 1.5 : 0.75)
            )
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .disabled(!isInteractive)
        // Entrance SLAM (new pills only). The pill rockets up from a small
        // scale, punches PAST full size to 1.2×, recoils to 0.94×, then
        // settles with a bouncy spring — a lively "stamp" instead of a plain
        // fade-up. Peak 1.2× is deliberately capped to fit the 8pt scroll
        // inset on either side, so the slam never gets clipped.
        .modifier(SlamEntrance(animate: animateEntrance))
        // One firm impact in sync with the slam landing. Fires only when
        // `landed` flips (new pills), never for pre-existing ones.
        .sensoryFeedback(.impact(weight: .medium, intensity: 1.0), trigger: landed)
        .onAppear {
            if animateEntrance { landed = true }
        }
    }

    private var pillStroke: Color {
        if isMine {
            // Strong enough that the pill reads as "mine" at a glance, but
            // it's the *outline* doing the work, not a saturated fill.
            return Color.purple.opacity(0.7)
        }
        return Color(uiColor: .separator)
    }
}

// MARK: - Slam entrance

/// The two animated channels of the entrance slam, driven by a keyframe track.
private struct SlamValues {
    var scale: CGFloat = 1
    var opacity: Double = 1
}

/// Plays the punchy entrance "slam" exactly once on appear — but ONLY for pills
/// that should animate in (`animate == true`, i.e. a brand-new reaction). Pills
/// already present when the bar loads take the `else` branch and render at full
/// size with no motion, so nothing pops when a card merely scrolls into view.
///
/// The keyframe timeline gives the slam its character a plain spring can't:
///   • scale rockets 0.4 → 1.2 (overshoot punch)
///   •          recoils 1.2 → 0.94 (the "impact")
///   •          settles 0.94 → 1.0 (bouncy)
///   • opacity snaps 0 → 1 fast so the punch is fully visible.
/// Peak 1.2× is intentionally modest: it stays within the 8pt scroll inset on
/// each side, so even the leading or trailing pill slams without being clipped.
private struct SlamEntrance: ViewModifier {
    let animate: Bool

    func body(content: Content) -> some View {
        if animate {
            content.keyframeAnimator(initialValue: SlamValues(scale: 0.4, opacity: 0)) { view, value in
                view
                    .scaleEffect(value.scale)
                    .opacity(value.opacity)
            } keyframes: { _ in
                KeyframeTrack(\.scale) {
                    SpringKeyframe(1.2, duration: 0.18, spring: .snappy)
                    SpringKeyframe(0.94, duration: 0.12, spring: .snappy)
                    SpringKeyframe(1.0, duration: 0.16, spring: .bouncy)
                }
                KeyframeTrack(\.opacity) {
                    LinearKeyframe(1.0, duration: 0.12)
                }
            }
        } else {
            content
        }
    }
}
