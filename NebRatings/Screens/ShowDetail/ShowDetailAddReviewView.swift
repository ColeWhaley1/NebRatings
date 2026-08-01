//
//  ShowDetailAddReviewView.swift
//  NebRatings
//
//  Add review form section for ShowDetailView.
//

import SwiftUI

struct ShowDetailAddReviewView: View {
    @Environment(NebRatingsStore.self) private var store: NebRatingsStore
    @Environment(\.colorScheme) private var colorScheme
    let displayShow: Show
    let reviews: () -> [Review]
    @Binding var filterSeason: Int?
    @Binding var newComment: String
    @Binding var newNebs: Double
    @FocusState.Binding var isCommentFocused: Bool
    @Binding var currentReviewPage: Int
    @Binding var reviewToEdit: Review?
    let userHasReviewForSeason: (Int?) -> Bool
    let userReviewForSeason: (Int?) -> Review?
    let onAddReview: () -> Void

    @State private var showObjectionableAlert = false

    private var formIsValid: Bool {
        !newComment.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// Runs the objectionable-content filter before posting (Guideline 1.2).
    private func attemptPost() {
        if ObjectionableContent.isObjectionable(newComment) {
            showObjectionableAlert = true
        } else {
            onAddReview()
        }
    }
    
    var body: some View {
        let seasonToReview: Int? = displayShow.category == .series ? filterSeason : nil
        
        VStack(alignment: .leading, spacing: 12) {
            if userHasReviewForSeason(seasonToReview), let existingReview = userReviewForSeason(seasonToReview) {
                VStack(alignment: .leading, spacing: 12) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Drop Your Nebs")
                            .font(.title3.bold())
                            .foregroundStyle(.primary)
                        
                        if displayShow.category == .series, let numberOfSeasons = displayShow.numberOfSeasons, numberOfSeasons > 0 {
                            HStack(spacing: 8) {
                                Text("Reviewing:")
                                    .font(.subheadline)
                                    .foregroundStyle(.primary)
                                
                                Picker("Review Season", selection: $filterSeason) {
                                    Text("Entire Show").tag(nil as Int?)
                                    ForEach(1...numberOfSeasons, id: \.self) { seasonNum in
                                        Text("Season \(seasonNum)").tag(seasonNum as Int?)
                                    }
                                }
                                .pickerStyle(.menu)
                                .foregroundStyle(.primary)
                                .padding(.leading, 0)
                            }
                            .onChange(of: filterSeason) { _, _ in
                                currentReviewPage = 0
                            }
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "info.circle")
                                .foregroundStyle(.secondary)
                            Text("You've already reviewed this")
                                .font(.headline)
                                .foregroundStyle(.primary)
                        }
                        
                        Text("Swipe left on your review below to edit or delete it.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        
                        Button {
                            if let reviewFromFilter = reviews().first(where: { $0.id == existingReview.id }) {
                                reviewToEdit = reviewFromFilter
                            } else {
                                reviewToEdit = existingReview
                            }
                        } label: {
                            Label("Edit Your Review", systemImage: "pencil.line")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .tint(.purple)
                    }
                }
                .padding()
                .background(
                    colorScheme == .dark
                        ? Color.purple.opacity(0.25)
                        : Color.purple.opacity(0.1),
                    in: RoundedRectangle(cornerRadius: 12)
                )
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Drop Your Nebs")
                            .font(.title3.bold())
                            .foregroundStyle(.primary)
                        
                        if displayShow.category == .series, let numberOfSeasons = displayShow.numberOfSeasons, numberOfSeasons > 0 {
                            HStack(spacing: 8) {
                                Text("Reviewing:")
                                    .font(.subheadline)
                                    .foregroundStyle(.primary)
                                
                                Picker("Review Season", selection: $filterSeason) {
                                    Text("Entire Show").tag(nil as Int?)
                                    ForEach(1...numberOfSeasons, id: \.self) { seasonNum in
                                        Text("Season \(seasonNum)").tag(seasonNum as Int?)
                                    }
                                }
                                .pickerStyle(.menu)
                                .foregroundStyle(.primary)
                                .padding(.leading, 0)
                            }
                            .onChange(of: filterSeason) { _, _ in
                                currentReviewPage = 0
                            }
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Rating")
                            .font(.subheadline.bold())
                            .foregroundStyle(.primary)
                        Slider(value: $newNebs, in: 0...10, step: 0.1)
                            .tint(.purple)
                        
                        HStack {
                            Button {
                                newNebs = max(0, newNebs - 0.1)
                            } label: {
                                Image(systemName: "minus.circle.fill")
                                    .font(.title2)
                                    .foregroundStyle(colorScheme == .dark ? Color.white : Color.black)
                                    .opacity(colorScheme == .dark ? 0.4 : 0.3)
                            }
                            .buttonStyle(.plain)
                            
                            Spacer()
                            
                            NebRatingView(rating: newNebs)
                            
                            Spacer()
                            
                            Button {
                                newNebs = min(10, newNebs + 0.1)
                            } label: {
                                Image(systemName: "plus.circle.fill")
                                    .font(.title2)
                                    .foregroundStyle(colorScheme == .dark ? Color.white : Color.black)
                                    .opacity(colorScheme == .dark ? 0.4 : 0.3)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        isCommentFocused = false
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Comment")
                            .font(.subheadline.bold())
                            .foregroundStyle(.primary)
                        TextEditor(text: $newComment)
                            .frame(minHeight: 120)
                            .scrollContentBackground(.hidden)
                            .background(Color(.systemBackground))
                            .foregroundColor(.primary)
                            .textSelection(.enabled)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(.separator), lineWidth: 1))
                            .contentMargins(4.0)
                            .focused($isCommentFocused)
                    }
                    
                    Button(action: attemptPost) {
                        Label("Post Review", systemImage: "paperplane.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.purple)
                    .disabled(!formIsValid)
                }
            }
        }
        .alert("Let's keep it civil", isPresented: $showObjectionableAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Your review appears to contain objectionable language. Please revise it before posting — NebRatings has zero tolerance for objectionable content.")
        }
    }
}
