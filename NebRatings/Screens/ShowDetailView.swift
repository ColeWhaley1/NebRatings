//
//  ShowDetailView.swift
//  NebRatings
//
//  Created by Cole Whaley on 11/29/25.
//

import SwiftUI

// PreferenceKey to measure review card heights
struct ReviewHeightPreferenceKey: PreferenceKey {
    static var defaultValue: [UUID: CGFloat] = [:]
    
    static func reduce(value: inout [UUID: CGFloat], nextValue: () -> [UUID: CGFloat]) {
        value.merge(nextValue()) { _, new in new }
    }
}

struct ShowDetailView: View {
    @Environment(NebRatingsStore.self) private var store: NebRatingsStore
    @Environment(\.dismiss) private var dismiss
    let show: Show

    @State private var newComment = ""
    @State private var newNebs: Double = 3
    @State private var detailedShow: Show?
    @State private var isProvidersExpanded = false
    @FocusState private var isCommentFocused: Bool
    @State private var reviewToEdit: Review?
    @State private var reviewHeights: [UUID: CGFloat] = [:]
    @State private var currentReviewPage: Int = 0
    @State private var expandedReview: Review?
    
    private var displayShow: Show {
        detailedShow ?? show
    }

    private func reviews() -> [Review] {
        // Use displayShow.id to ensure we use the correct ID even if detailedShow was loaded
        let showID = displayShow.id
        let filtered = store.reviews.filter { $0.showID == showID }
        print("📊 Filtered reviews: \(filtered.count) reviews for showID: \(showID)")
        print("📊 Total reviews in store: \(store.reviews.count)")
        if filtered.isEmpty && !store.reviews.isEmpty {
            print("⚠️ No reviews matched! Sample review showIDs:")
            for review in store.reviews.prefix(3) {
                print("  - Review showID: \(review.showID), title: \(review.showTitle)")
            }
        }
        
        // Sort reviews: user's review first, then by timestamp (newest first)
        let currentUserName = store.currentUser?.name
        let sorted = filtered.sorted { review1, review2 in
            let isReview1Own = review1.author == currentUserName
            let isReview2Own = review2.author == currentUserName
            
            // User's own review always comes first
            if isReview1Own && !isReview2Own {
                return true
            }
            if !isReview1Own && isReview2Own {
                return false
            }
            
            // If both are own reviews or both are not, sort by timestamp (newest first)
            return review1.timestamp > review2.timestamp
        }
        
        // Return all reviews (no limit, pagination handled in UI)
        return sorted
    }
    
    private var userHasReview: Bool {
        guard let currentUser = store.currentUser else { return false }
        let showID = displayShow.id
        return store.reviews.contains { review in
            review.showID == showID && review.author == currentUser.name
        }
    }
    
    private var userReview: Review? {
        guard let currentUser = store.currentUser else { return nil }
        let showID = displayShow.id
        return store.reviews.first { review in
            review.showID == showID && review.author == currentUser.name
        }
    }
    
    private func calculateTotalHeight(for reviews: [Review]) -> CGFloat {
        let totalHeight = reviews.reduce(0.0) { total, review in
            // Height already includes row insets from the preference
            let rowHeight = reviewHeights[review.id] ?? 176 // Fallback: 160 card + 16 insets
            return total + rowHeight
        }
        return totalHeight
    }
    

    private var yearFormatted: String {
        return "\(displayShow.year)"
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // Backdrop image - only show if backdrop exists
                if let backdropURL = displayShow.backdropURL, !backdropURL.isEmpty {
                    AsyncImageView(urlString: backdropURL)
                        .frame(height: 250)
                        .frame(maxWidth: .infinity)
                        .clipped()
                }
                
                HStack(spacing: 20) {
                    Spacer()
                        .frame(width: 20)
                    VStack(alignment: .leading, spacing: 24) {
                        header
                        Divider()
                            .background(Color(.separator))
                        reviewsSection
                        Divider()
                            .background(Color(.separator))
                        addReviewSection
                        Divider()
                            .background(Color(.separator))
                        recommendationsSection
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    Spacer()
                        .frame(width: 20)
                }
                .padding(.vertical, 20)
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color(.systemGroupedBackground))
        .navigationTitle(displayShow.title)
        .navigationBarTitleDisplayMode(.inline)
        .onTapGesture {
            // Dismiss keyboard when tapping outside text fields
            isCommentFocused = false
        }
        .task {
            await loadShowDetails()
            await loadShowReviews()
            await loadRecommendations()
        }
    }
    
    private func loadShowDetails() async {
        // show.id is now the TMDB ID, so we can fetch details if genres are empty
        if show.genres.isEmpty {
            if let detailed = await store.fetchShowDetailsByTMDBID(tmdbID: show.id, category: show.category) {
                detailedShow = detailed

                // Now requery reviews with the correct id
                await loadShowReviews()
                await loadRecommendations()
            }
        }
    }

    
    private func loadShowReviews() async {
        // Use displayShow.id directly - it's now the TMDB ID
        let showID = displayShow.id
        print("🔍 Loading reviews for showID: \(showID)")
        await store.queryReviews(showID: showID)
    }
    
    private func loadRecommendations() async {
        await store.loadRecommendations(for: displayShow)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Poster and basic info in a row
            HStack(alignment: .top, spacing: 16) {
                // Poster - only show if poster exists
                if displayShow.posterURL != nil {
                    AsyncImageView(urlString: displayShow.posterURL)
                        .frame(width: 100, height: 150)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color(.separator), lineWidth: 1)
                        )
                }
                
                // Basic info column
                VStack(alignment: .leading, spacing: 8) {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 6) {
                            Image(systemName: "calendar")
                                .foregroundStyle(.secondary)
                                .font(.subheadline)
                            Text(yearFormatted)
                                .foregroundStyle(.primary)
                                .font(.subheadline)
                        }
                        
                        if !displayShow.watchProviders.isEmpty {
                            if displayShow.watchProviders.count == 1, let provider = displayShow.watchProviders.first {
                                // Single provider - display directly
                                HStack(spacing: 6) {
                                    if let logoURL = provider.logoURL {
                                        AsyncImageView(urlString: logoURL)
                                            .frame(width: 24, height: 24)
                                            .clipShape(RoundedRectangle(cornerRadius: 4))
                                    }
                                    Text(provider.name)
                                        .font(.subheadline)
                                        .foregroundStyle(.primary)
                                }
                            } else {
                                // Multiple providers - use dropdown
                                DisclosureGroup(isExpanded: $isProvidersExpanded) {
                                    VStack(alignment: .leading, spacing: 8) {
                                        ForEach(displayShow.watchProviders) { provider in
                                            HStack(spacing: 6) {
                                                if let logoURL = provider.logoURL {
                                                    AsyncImageView(urlString: logoURL)
                                                        .frame(width: 24, height: 24)
                                                        .clipShape(RoundedRectangle(cornerRadius: 4))
                                                }
                                                Text(provider.name)
                                                    .font(.subheadline)
                                                    .foregroundStyle(.primary)
                                            }
                                        }
                                    }
                                    .padding(.top, 4)
                                } label: {
                                    HStack(spacing: 6) {
                                        Image(systemName: "play.tv")
                                            .foregroundStyle(.secondary)
                                            .font(.subheadline)
                                        Text("Where to watch")
                                            .font(.subheadline)
                                            .foregroundStyle(.primary)
                                        Text("(\(displayShow.watchProviders.count))")
                                            .font(.subheadline)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                .transaction { transaction in
                                    transaction.animation = nil
                                }
                            }
                        } else if !displayShow.streamingService.isEmpty && displayShow.streamingService != "Various" {
                            HStack(spacing: 6) {
                                Image(systemName: "play.tv")
                                    .foregroundStyle(.secondary)
                                    .font(.subheadline)
                                Text(displayShow.streamingService)
                                    .foregroundStyle(.primary)
                                    .font(.subheadline)
                            }
                        }
                        
                        if let rating = displayShow.rating, rating > 0 {
                            HStack(spacing: 6) {
                                Image(systemName: "star.fill")
                                    .foregroundStyle(.yellow)
                                    .font(.subheadline)
                                Text(String(format: "%.1f", rating))
                                    .foregroundStyle(.primary)
                                    .font(.subheadline)
                            }
                        }
                    }
                    
                    if displayShow.averageNebs > 0 {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 8) {
                                NebRatingView(rating: displayShow.averageNebs)
                                Text("\(displayShow.reviews.count) reviews")
                                    .font(.subheadline)
                                    .foregroundStyle(.primary)
                            }
                        }
                        .padding(.top, 4)
                    }
                }
                .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
            }
            
            // Synopsis
            Text(displayShow.synopsis)
                .font(.body)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
            
            // Genres
            if !displayShow.genres.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(displayShow.genres, id: \.self) { genre in
                            Text(genre)
                                .font(.caption)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Color.purple.opacity(0.2))
                                .foregroundStyle(.primary)
                                .clipShape(Capsule())
                        }
                    }
                }
            }
            
            // Attribution at bottom
            if displayShow.tmdbID != nil {
                VStack(alignment: .leading, spacing: 2) {
                    if !displayShow.watchProviders.isEmpty {
                        Text("Streaming data provided by JustWatch")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                    Text("Data provided by TMDB")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                .padding(.top, 4)
            }
        }
    }

    private var recommendationsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("You may also like...")
                .font(.title3.bold())
                .foregroundStyle(.primary)
            
            if store.isLoadingRecommendations {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding()
            } else if store.recommendations.isEmpty {
                ContentUnavailableView("No recommendations", systemImage: "sparkles", description: Text("Similar shows will appear here."))
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 16) {
                        ForEach(store.recommendations) { recommendedShow in
                            NavigationLink(value: recommendedShow) {
                                VStack(alignment: .leading, spacing: 8) {
                                    AsyncImageView(urlString: recommendedShow.posterURL)
                                        .frame(width: 120, height: 180)
                                        .clipShape(RoundedRectangle(cornerRadius: 12))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12)
                                                .stroke(Color(.separator), lineWidth: 1)
                                        )
                                    
                                    Text(recommendedShow.title)
                                        .font(.subheadline.bold())
                                        .foregroundStyle(.primary)
                                        .lineLimit(2)
                                        .frame(width: 120, alignment: .leading)
                                    
                                    Text(String(recommendedShow.year))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 4)
                }
            }
        }
    }
    
    @ViewBuilder
    private var reviewsSection: some View {
        
        let allReviews = reviews()
        let reviewPages = chunkReviews(allReviews, pageSize: 5)
        
        VStack(alignment: .leading, spacing: 4) {
            // Header with title and navigation arrows
            HStack {
                Text("Neb Reviews")
                    .font(.title3.bold())
                    .foregroundStyle(.primary)
                
                Spacer()
                
                if !allReviews.isEmpty && reviewPages.count > 1 {
                    // Left arrow
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            if currentReviewPage > 0 {
                                currentReviewPage -= 1
                            }
                        }
                    }) {
                        Image(systemName: "chevron.left")
                            .font(.title3)
                            .foregroundStyle(currentReviewPage > 0 ? Color.primary : Color.gray.opacity(0.3))
                            .frame(width: 32, height: 32)
                    }
                    .disabled(currentReviewPage == 0)
                    
                    // Right arrow
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            if currentReviewPage < reviewPages.count - 1 {
                                currentReviewPage += 1
                            }
                        }
                    }) {
                        Image(systemName: "chevron.right")
                            .font(.title3)
                            .foregroundStyle(currentReviewPage < reviewPages.count - 1 ? Color.primary : Color.gray.opacity(0.3))
                            .frame(width: 32, height: 32)
                    }
                    .disabled(currentReviewPage >= reviewPages.count - 1)
                }
            }
            .padding(.bottom, 8)
            
            if allReviews.isEmpty {
                ContentUnavailableView("No reviews yet", systemImage: "bubble.left.and.exclamationmark", description: Text("Be the first to drop some nebs."))
            } else {
                VStack(spacing: 12) {
                    // TabView for smooth page transitions with full-width cards
                    TabView(selection: $currentReviewPage) {
                        ForEach(0..<reviewPages.count, id: \.self) { pageIndex in
                            HStack(spacing: 0) {
                                // Left spacing
                                Spacer()
                                    .frame(width: 8)
                                
                                // Content area with full-width cards
                                VStack(spacing: 8) {
                                    ForEach(reviewPages[pageIndex]) { review in
                                        let isOwnReview = store.currentUser?.name == review.author
                                        ReviewCard(
                                            review: review,
                                            showCategory: review.showCategory,
                                            isOwnReview: isOwnReview,
                                            onTap: {
                                                expandedReview = review
                                            }
                                        )
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                            if isOwnReview {
                                                Button {
                                                    store.deleteReview(review)
                                                } label: {
                                                    Label("Delete", systemImage: "trash")
                                                        .symbolRenderingMode(.hierarchical)
                                                }
                                                .tint(Color.red.opacity(0.7))
                                                
                                                Button {
                                                    reviewToEdit = review
                                                } label: {
                                                    Label("Edit", systemImage: "pencil.line")
                                                }
                                                .tint(Color.blue.opacity(0.7))
                                            }
                                        }
                                    }
                                }
                                .frame(maxWidth: .infinity)
                                
                                // Right spacing
                                Spacer()
                                    .frame(width: 8)
                            }
                            .tag(pageIndex)
                        }
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                    .frame(height: calculateMaxCarouselHeight(for: reviewPages))
                    .animation(.easeInOut(duration: 0.3), value: currentReviewPage)
                    
                    // Page indicator
                    if reviewPages.count > 1 {
                        HStack(spacing: 6) {
                            ForEach(0..<reviewPages.count, id: \.self) { index in
                                Circle()
                                    .fill(index == currentReviewPage ? Color.primary : Color.gray.opacity(0.3))
                                    .frame(width: 8, height: 8)
                            }
                        }
                        .padding(.top, 4)
                    }
                }
            }
        }
        .sheet(item: $reviewToEdit) { review in
            EditReviewView(review: review)
                .environment(store)
        }
        .sheet(item: $expandedReview) { review in
            ExpandedReviewView(review: review)
        }
        .onChange(of: allReviews.count) { _, _ in
            // Reset to first page if reviews change
            if currentReviewPage > 0 && allReviews.isEmpty {
                currentReviewPage = 0
            }
        }
    }
    
    private func chunkReviews(_ reviews: [Review], pageSize: Int) -> [[Review]] {
        var chunks: [[Review]] = []
        for i in stride(from: 0, to: reviews.count, by: pageSize) {
            let chunk = Array(reviews[i..<min(i + pageSize, reviews.count)])
            chunks.append(chunk)
        }
        return chunks
    }
    
    private func calculateCarouselHeight(for reviews: [Review]) -> CGFloat {
        // Fixed height: 180pt per review card + 8pt spacing between cards
        let cardHeight: CGFloat = 180
        let spacing: CGFloat = 8
        let totalHeight = CGFloat(reviews.count) * cardHeight + CGFloat(max(0, reviews.count - 1)) * spacing
        return max(totalHeight, cardHeight)
    }
    
    private func calculateMaxCarouselHeight(for reviewPages: [[Review]]) -> CGFloat {
        // Fixed height: 180pt per review card + 8pt spacing between cards
        // Max 5 reviews per page
        let cardHeight: CGFloat = 180
        let spacing: CGFloat = 8
        let maxReviewsPerPage = 5
        let totalHeight = CGFloat(maxReviewsPerPage) * cardHeight + CGFloat(maxReviewsPerPage - 1) * spacing
        return totalHeight
    }

    private var addReviewSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            if userHasReview, let existingReview = userReview {
                // User already has a review - show message to edit instead
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
                    
                    Button(action: {
                        reviewToEdit = existingReview
                    }) {
                        Label("Edit Your Review", systemImage: "pencil.line")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .tint(.purple)
                }
                .padding()
                .background(Color.purple.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
            } else {
                // User doesn't have a review - show the form
                Text("Drop Your Nebs")
                    .font(.title3.bold())
                    .foregroundStyle(.primary)
                VStack(alignment: .leading, spacing: 12) {
                    Text("Rating")
                        .font(.subheadline.bold())
                        .foregroundStyle(.primary)
                    NebRatingView(rating: newNebs)
                    Slider(value: $newNebs, in: 0...5, step: 0.5)
                        .tint(.purple)
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
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(.separator), lineWidth: 1))
                        .contentMargins(4.0)
                        .focused($isCommentFocused)
                }
                Button(action: addReview) {
                    Label("Post Review", systemImage: "paperplane.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.purple)
                .disabled(!formIsValid)
            }
        }
    }

    private var formIsValid: Bool {
        !newComment.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func addReview() {
        guard formIsValid else { return }
        let authorName = store.currentUser?.name ?? "Anonymous"
        // Use displayShow to ensure we use the show with the correct ID
        // Both show and detailedShow should have the same ID if they have the same tmdbID
        store.addReview(author: authorName,
                        comment: newComment.trimmingCharacters(in: .whitespacesAndNewlines),
                        rating: newNebs,
                        to: displayShow)
        newComment = ""
        newNebs = 3
        // Dismiss keyboard
        isCommentFocused = false
    }
}


#Preview {
    let show = Show.previewData[0]
    let store = NebRatingsStore()
    
    return NavigationStack {
        ShowDetailView(show: show)
            .environment(store)
    }
}

#Preview("Without Poster") {
    let show = Show.previewData[4] // No poster show
    let store = NebRatingsStore()
    
    return NavigationStack {
        ShowDetailView(show: show)
            .environment(store)
    }
}

#Preview("With Many Reviews") {
    let show = Show.previewData[2] // The Dark Knight
    let store = NebRatingsStore()
    
    // Generate 20 reviews for this show
    let now = Date()
    let calendar = Calendar.current
    let showID = show.id
    let sampleAuthors = ["Alex", "Sarah", "Mike", "Emma", "Jordan", "Chris", "Taylor", "Riley", "Morgan", "Casey", "Drew", "Jamie", "Quinn", "Parker", "Sam", "Blake", "Cameron", "Avery", "Reese", "Dakota"]
    let sampleComments = [
        // Very short comments
        "Perfect!",
        "Amazing film.",
        "Loved it!",
        
        // Medium comments
        "Absolutely incredible! One of the best superhero movies ever made.",
        "Heath Ledger's performance as the Joker is legendary. Oscar-worthy!",
        "The action sequences are mind-blowing. The bank heist opening is perfect.",
        "Christopher Nolan's direction is masterful. Every scene is perfectly crafted.",
        "The Dark Knight elevates the superhero genre to new heights.",
        
        // Long comments
        "Intense, gripping, and emotionally powerful. A true masterpiece that redefined what superhero movies could be. The way Christopher Nolan weaves together complex themes of justice, morality, and chaos is nothing short of brilliant. Heath Ledger's Joker is not just a villain, but a force of nature that challenges everything Batman stands for. Every viewing reveals new layers and subtleties that I missed before.",
        "The cinematography is stunning. Gotham feels real and lived-in, creating an atmosphere that perfectly matches the dark tone of the story. Wally Pfister's work here is exemplary - the way he uses shadows and light to create tension is masterful. The practical effects, especially in the truck flip scene, are absolutely breathtaking. This is filmmaking at its finest.",
        "Aaron Eckhart as Two-Face is also fantastic. His transformation from Harvey Dent, the White Knight of Gotham, into the vengeful Two-Face is both heartbreaking and terrifying. The character arc is perfectly executed, showing how tragedy can corrupt even the most noble of souls. The makeup effects are incredible and add to the horror of the character.",
        "The moral complexity makes this more than just a comic book movie. It asks deep questions about what justice truly means, whether the ends justify the means, and how society can maintain order in the face of chaos. The film doesn't provide easy answers, instead forcing the audience to grapple with these difficult themes. This philosophical depth elevates it far above typical genre fare.",
        "The pacing is perfect. Despite its nearly three-hour runtime, the film never feels slow or bloated. Every scene serves a purpose, every line of dialogue matters. The tension builds relentlessly from the opening bank heist to the climactic confrontation with the Joker. It's a masterclass in narrative structure and pacing.",
        "One of those rare sequels that's better than the original. While Batman Begins was excellent, The Dark Knight takes everything that worked and amplifies it to perfection. The stakes are higher, the villains are more compelling, and the emotional impact is greater. This is how you make a sequel that surpasses its predecessor.",
        "The score by Hans Zimmer and James Newton Howard is incredible. The theme for the Joker, with its jarring, dissonant strings, perfectly captures the character's chaotic nature. The Batman theme builds on what was established in the first film, becoming more heroic and powerful. The music enhances every scene, creating an atmosphere that is both epic and intimate. It gives me chills every single time I hear it.",
        "This is what all superhero movies should strive to be. It proves that comic book adaptations can be serious, thought-provoking cinema while still delivering thrilling action and spectacle. The Dark Knight doesn't talk down to its audience or rely on shallow spectacle - it respects the intelligence of viewers and delivers a complex, emotionally resonant story.",
        "Rewatched it recently and it still holds up perfectly. More than a decade later, this film feels as fresh and impactful as it did on first viewing. The themes remain relevant, the performances are still astonishing, and the technical achievements continue to impress. It's a timeless work of art that will be studied and admired for generations to come.",
        "The practical effects make all the difference. There's no over-reliance on CGI here - real stunts, real explosions, real buildings being destroyed. This gives the action sequences weight and authenticity that many modern films lack. The truck flip scene, where an actual truck was flipped using a cable system, is one of the most impressive stunts ever filmed. It's the kind of practical filmmaking that makes you appreciate the craft.",
        "Christian Bale is the definitive Batman in my opinion. His portrayal captures both the tortured soul of Bruce Wayne and the calculated intensity of Batman. He brings gravitas and emotional depth to the role that few actors could match. The voice he uses for Batman might be a bit much for some, but it works perfectly in the context of the film - it's intimidating and distinct.",
        "The truck flip scene is one of the most impressive stunts ever filmed. The fact that they actually flipped a real truck using cables and explosives is mind-boggling. It's the kind of practical filmmaking that makes you appreciate the dedication and skill of the crew. The scene is perfectly shot and edited, creating a moment of pure cinematic spectacle that is both thrilling and awe-inspiring.",
        "Philosophically rich while still being entertaining. The film explores deep questions about justice, morality, and the nature of heroism without ever feeling pretentious or preachy. The Joker's philosophy of chaos versus Batman's belief in order creates a fascinating moral and philosophical debate that runs throughout the film. It's rare to find a blockbuster that can be this intellectually stimulating while still being thoroughly entertaining.",
        "The ending is perfect. Sets up the sequel beautifully while also providing a satisfying conclusion to this chapter of the story. Batman's decision to take the blame for Harvey Dent's crimes in order to preserve his legacy shows true heroism - he sacrifices his own reputation for the greater good. The final shot of Batman running from the police, with Commissioner Gordon's narration, is both haunting and inspiring."
    ]
    let ratings: [Double] = [5.0, 5.0, 5.0, 4.5, 5.0, 4.5, 5.0, 4.0, 5.0, 4.5, 5.0, 5.0, 4.0, 5.0, 4.5, 5.0, 4.5, 5.0, 4.5, 5.0]
    
    var reviews: [Review] = []
    for i in 0..<20 {
        let daysAgo = i
        let hoursAgo = i * 2
        reviews.append(Review(
            showID: showID,
            showTitle: show.title,
            showCategory: show.category,
            author: sampleAuthors[i],
            comment: sampleComments[i],
            nebRating: ratings[i],
            timestamp: calendar.date(byAdding: .hour, value: -hoursAgo, to: now) ?? now
        ))
    }
    
    // Sort by timestamp (newest first)
    store.reviews = reviews.sorted { $0.timestamp > $1.timestamp }
    
    return NavigationStack {
        ShowDetailView(show: show)
            .environment(store)
    }
}

