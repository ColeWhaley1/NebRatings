//
//  CompatibilityView.swift
//  NebRatings
//
//  "Compare Tastes" — a compatibility % between the signed-in user and
//  another user, with the insight breakdown (both love / disagree on /
//  shared favorites / biggest rating gaps). Pushed from UserProfileView.
//

import SwiftUI

struct CompatibilityView: View {
    let otherUserID: String
    let otherProfile: UserProfile?
    /// Pre-computed report that skips the async Firestore load — used to
    /// render this exact screen with sample data for marketing screenshots
    /// (see MarketingSnapshotView). nil in every real code path.
    var snapshot: (report: CompatibilityReport, myAvatarEmoji: String?)? = nil

    @Environment(NebRatingsStore.self) private var store
    @State private var report: CompatibilityReport?
    @State private var isLoading = true
    /// Drives the score ring sweep after the report lands.
    @State private var ringProgress: Double = 0

    private var otherName: String {
        otherProfile?.username ?? "them"
    }

    var body: some View {
        ScrollView {
            if isLoading {
                ProgressView("Comparing tastes…")
                    .frame(maxWidth: .infinity)
                    .padding(.top, 120)
            } else if let report {
                VStack(spacing: 24) {
                    scoreHeader(report)

                    if report.isLowConfidence {
                        Label("Not much overlap yet — rate more of the same titles for a sharper score.", systemImage: "info.circle")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 24)
                    }

                    if !report.bothLove.isEmpty {
                        insightSection(title: "You both love", icon: "heart.fill", tint: .pink) {
                            GenreChipsView(genres: report.bothLove)
                        }
                    }

                    if !report.disagreeOn.isEmpty {
                        insightSection(title: "You disagree on", icon: "bolt.horizontal.fill", tint: .orange) {
                            GenreChipsView(genres: report.disagreeOn)
                        }
                    }

                    if !report.sharedFavorites.isEmpty {
                        insightSection(title: "Shared favorites", icon: "star.fill", tint: .yellow) {
                            VStack(spacing: 8) {
                                ForEach(report.sharedFavorites) { favorite in
                                    HStack {
                                        Text(favorite.title)
                                            .font(.subheadline)
                                            .lineLimit(1)
                                        Spacer(minLength: 8)
                                        ratingPair(mine: favorite.myRating, theirs: favorite.theirRating)
                                    }
                                    .padding(10)
                                    .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 10))
                                }
                            }
                        }
                    }

                    if !report.biggestDifferences.isEmpty {
                        insightSection(title: "Biggest rating differences", icon: "arrow.up.arrow.down", tint: .purple) {
                            VStack(spacing: 8) {
                                ForEach(report.biggestDifferences) { difference in
                                    HStack {
                                        Text(difference.title)
                                            .font(.subheadline)
                                            .lineLimit(1)
                                        Spacer(minLength: 8)
                                        Text(String(format: "%+.1f", difference.delta))
                                            .font(.subheadline.bold())
                                            .foregroundStyle(difference.delta > 0 ? .teal : .orange)
                                        ratingPair(mine: difference.myRating, theirs: difference.theirRating)
                                    }
                                    .padding(10)
                                    .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 10))
                                }
                            }
                        }
                    }

                    Text("Based on \(report.sharedTitleCount) shared \(report.sharedTitleCount == 1 ? "title" : "titles"), your genres, and your favorites.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .padding(.bottom, 20)
                }
                .padding(.top, 24)
            }
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Compare Tastes")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            if let snapshot {
                report = snapshot.report
                isLoading = false
            } else {
                await load()
            }
        }
    }

    // MARK: - Pieces

    private func scoreHeader(_ report: CompatibilityReport) -> some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .stroke(Color.purple.opacity(0.15), lineWidth: 14)
                Circle()
                    .trim(from: 0, to: ringProgress)
                    .stroke(
                        AngularGradient(
                            colors: [.purple, .pink, .purple],
                            center: .center
                        ),
                        style: StrokeStyle(lineWidth: 14, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                VStack(spacing: 0) {
                    Text("\(report.score)%")
                        .font(.system(size: 44, weight: .bold, design: .rounded))
                        .contentTransition(.numericText())
                    Text("Compatibility")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 180, height: 180)

            HStack(spacing: 10) {
                AvatarView(emoji: snapshot?.myAvatarEmoji ?? store.currentUser?.avatarEmoji, size: 40)
                Image(systemName: "heart.fill")
                    .foregroundStyle(.pink)
                    .font(.caption)
                AvatarView(emoji: otherProfile?.avatarEmoji, size: 40)
            }

            Text("You & \(otherName)")
                .font(.headline)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 1.0).delay(0.15)) {
                ringProgress = Double(report.score) / 100.0
            }
        }
    }

    @ViewBuilder
    private func insightSection<Content: View>(title: String,
                                               icon: String,
                                               tint: Color,
                                               @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundStyle(tint)
                Text(title)
                    .font(.subheadline.bold())
                    .foregroundStyle(.secondary)
            }
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
    }

    /// "🔥 8.5 · 9.0" — my rating then theirs.
    private func ratingPair(mine: Double, theirs: Double) -> some View {
        Text(String(format: "%.1f · %.1f", mine, theirs))
            .font(.caption.bold())
            .foregroundStyle(.secondary)
            .monospacedDigit()
    }

    private func load() async {
        let theirReviews = await store.fetchReviews(for: otherUserID)
        var theirProfile = otherProfile
        if theirProfile == nil {
            theirProfile = await store.fetchProfile(userID: otherUserID)
        }
        report = CompatibilityEngine.report(
            myReviews: store.userReviews,
            theirReviews: theirReviews,
            myProfile: store.currentUser,
            theirProfile: theirProfile
        )
        isLoading = false
    }
}
