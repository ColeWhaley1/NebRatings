//
//  EditReviewView.swift
//  NebRatings
//
//  Created by Cole Whaley on 11/29/25.
//

import SwiftUI

struct EditReviewView: View {
    let review: Review
    @Environment(NebRatingsStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    
    @State private var comment: String
    @State private var rating: Double
    @FocusState private var isCommentFocused: Bool
    @Environment(\.colorScheme) private var colorScheme
    
    init(review: Review) {
        self.review = review
        _comment = State(initialValue: review.comment)
        // Ratings are stored on 0-10 scale directly
        _rating = State(initialValue: review.nebRating)
    }
    
    private var formIsValid: Bool {
        !comment.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
            rating >= 0 && rating <= 10
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Rating")
                            .font(.subheadline.bold())
                            .foregroundStyle(.primary)
                            
                        Slider(value: $rating, in: 0 ... 10, step: 0.1)
                            .tint(.purple)
                            
                        HStack {
                            Button(action: {
                                rating = max(0, rating - 0.1)
                            }) {
                                Image(systemName: "minus.circle.fill")
                                    .font(.title2)
                                    .foregroundStyle(colorScheme == .dark ? Color.white : Color.black)
                                    .opacity(colorScheme == .dark ? 0.5 : 0.4)
                            }
                            .buttonStyle(.plain)
                                
                            Spacer()
                                
                            NebRatingView(rating: rating)
                                
                            Spacer()
                                
                            Button(action: {
                                rating = min(10, rating + 0.1)
                            }) {
                                Image(systemName: "plus.circle.fill")
                                    .font(.title2)
                                    .foregroundStyle(colorScheme == .dark ? Color.white : Color.black)
                                    .opacity(colorScheme == .dark ? 0.5 : 0.4)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.vertical, 8)
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        isCommentFocused = false
                    }
                }
                    
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Your Review")
                            .font(.subheadline.bold())
                            .foregroundStyle(.primary)
                            
                        TextEditor(text: $comment)
                            .frame(minHeight: 120)
                            .focused($isCommentFocused)
                            .textSelection(.enabled)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(isCommentFocused ? Color.purple : Color.gray.opacity(0.3), lineWidth: 1)
                            )
                    }
                }
                        
                Section {
                    Button(action: saveReview) {
                        HStack {
                            Spacer()
                            Text("Save Changes")
                                .font(.headline)
                                .foregroundStyle(.white)
                            Spacer()
                        }
                        .padding(.vertical, 12)
                        .background(formIsValid ? Color.purple : Color.gray.opacity(0.3), in: RoundedRectangle(cornerRadius: 10))
                    }
                    .disabled(!formIsValid)
                }
            }
            .scrollContentBackground(.hidden)
            .scrollDismissesKeyboard(.interactively)
            .background(
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture {
                        isCommentFocused = false
                    }
            )
            .navigationTitle("Edit Review")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }

    private func saveReview() {
        guard formIsValid else { return }
        // Ratings are stored directly on 0-10 scale
        store.updateReview(review, comment: comment, rating: rating)
        dismiss()
    }
}

#Preview {
    let review = Review.sampleData[0]
    let store = NebRatingsStore()
    
    return EditReviewView(review: review)
        .environment(store)
}
