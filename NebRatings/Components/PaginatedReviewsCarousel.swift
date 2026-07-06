//
//  PaginatedReviewsCarousel.swift
//  NebRatings
//
//  Reusable, swipeable carousel for paginated review lists. Used by:
//    • ProfileView           — your own reviews (with sort picker)
//    • UserProfileView       — a friend's reviews
//    • ShowDetailReviewsView — community reviews on a show (with swipe-to-edit/delete)
//
//  The component is intentionally narrow: it lays out the pages, the chevron
//  controls, and the page indicator, and it clamps `currentPage` when the
//  underlying reviews array shrinks. Sort/filter UI is composed alongside
//  (see `ReviewSortPicker`) — each caller has different sort/filter needs
//  and stays in charge of producing the already-sorted `reviews` array.
//

import SwiftUI

// MARK: - Style

/// How each page lays out its review cards.
///
/// - `stacked`: a plain `VStack`. Lightweight; use when you don't need
///   `.swipeActions` on cards. Safe to nest inside a parent `List`.
/// - `swipeable`: each page is a transparent `List`, so `cardBuilder`
///   may attach `.swipeActions` modifiers that work as expected.
enum PaginatedReviewsCarouselStyle {
    case stacked
    case swipeable
}

// MARK: - Carousel

struct PaginatedReviewsCarousel<Card: View>: View {
    let reviews: [Review]
    let pageSize: Int
    @Binding var currentPage: Int
    let style: PaginatedReviewsCarouselStyle
    /// Shown as a faint footer on the last page when it has fewer than
    /// `pageSize` cards. e.g. "Keep reviewing to see more!"
    let partialPageMessage: String?
    let cardBuilder: (Review) -> Card

    init(reviews: [Review],
         pageSize: Int = 5,
         currentPage: Binding<Int>,
         style: PaginatedReviewsCarouselStyle = .stacked,
         partialPageMessage: String? = nil,
         @ViewBuilder cardBuilder: @escaping (Review) -> Card) {
        self.reviews = reviews
        self.pageSize = pageSize
        self._currentPage = currentPage
        self.style = style
        self.partialPageMessage = partialPageMessage
        self.cardBuilder = cardBuilder
    }

    var body: some View {
        let pages = ReviewPagination.chunkReviews(reviews, pageSize: pageSize)

        Group {
            if pages.isEmpty {
                EmptyView()
            } else {
                VStack(spacing: 12) {
                    TabView(selection: $currentPage) {
                        ForEach(0..<pages.count, id: \.self) { idx in
                            pageContent(reviews: pages[idx])
                                .tag(idx)
                        }
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                    .frame(height: ReviewPagination.carouselHeight(for: reviews, pageSize: pageSize))

                    pageIndicator(pageCount: pages.count)
                }
                .onChange(of: reviews.count) { _, newCount in
                    let count = max(1, ReviewPagination.pageCount(for: newCount, pageSize: pageSize))
                    if currentPage >= count {
                        currentPage = max(0, count - 1)
                    }
                }
            }
        }
    }

    // MARK: Page layouts

    @ViewBuilder
    private func pageContent(reviews pageReviews: [Review]) -> some View {
        HStack(spacing: 0) {
            Spacer().frame(width: 8)
            switch style {
            case .stacked:
                stackedPage(reviews: pageReviews)
            case .swipeable:
                swipeablePage(reviews: pageReviews)
            }
            Spacer().frame(width: 8)
        }
    }

    @ViewBuilder
    private func stackedPage(reviews pageReviews: [Review]) -> some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                ForEach(pageReviews) { review in
                    cardBuilder(review)
                }
                if let msg = partialPageMessage, pageReviews.count < pageSize {
                    partialPageFooter(message: msg)
                }
            }
            .padding(.vertical, 8)
        }
        .scrollDisabled(true)
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    @ViewBuilder
    private func swipeablePage(reviews pageReviews: [Review]) -> some View {
        List {
            ForEach(pageReviews) { review in
                cardBuilder(review)
                    .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
            }
            if let msg = partialPageMessage, pageReviews.count < pageSize {
                partialPageFooter(message: msg)
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .scrollDisabled(true)
        .environment(\.defaultMinListRowHeight, 0)
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    @ViewBuilder
    private func partialPageFooter(message: String) -> some View {
        VStack(spacing: 0) {
            Spacer().frame(height: 12)
            Text(message)
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.top, 4)
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private func pageIndicator(pageCount: Int) -> some View {
        if pageCount > 1 {
            Group {
                if pageCount > 10 {
                    Text("\(currentPage + 1) of \(pageCount)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    HStack(spacing: 6) {
                        ForEach(0..<pageCount, id: \.self) { idx in
                            Circle()
                                .fill(idx == currentPage ? Color.primary : Color.gray.opacity(0.3))
                                .frame(width: 8, height: 8)
                        }
                    }
                }
            }
            .padding(.top, 4)
            .padding(.bottom, 16)
        }
    }
}

// MARK: - Chevrons

/// Prev/next chevron pair. Caller decides where to place it (typically in
/// the header row above the carousel). Renders nothing for a single page.
struct ReviewPagerChevrons: View {
    let pageCount: Int
    @Binding var currentPage: Int
    var size: CGFloat = 32
    var font: Font = .title3

    var body: some View {
        if pageCount > 1 {
            HStack(spacing: 8) {
                chevronButton(
                    systemName: "chevron.left",
                    isEnabled: currentPage > 0
                ) { if currentPage > 0 { currentPage -= 1 } }

                chevronButton(
                    systemName: "chevron.right",
                    isEnabled: currentPage < pageCount - 1
                ) { if currentPage < pageCount - 1 { currentPage += 1 } }
            }
        }
    }

    private func chevronButton(systemName: String, isEnabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(font)
                .foregroundStyle(isEnabled ? Color.primary : Color.gray.opacity(0.3))
                .frame(width: size, height: size)
                .contentShape(Rectangle())
        }
        .disabled(!isEnabled)
        .buttonStyle(.plain)
    }
}

// MARK: - Count badge

/// Small "N reviews" pill shown in review-list headers. Pluralizes the
/// label and uses `.secondary` foreground over a soft tint, so it reads
/// clearly without competing with the title.
struct ReviewCountBadge: View {
    let count: Int

    var body: some View {
        Text("\(count) \(count == 1 ? "review" : "reviews")")
            .font(.caption.bold())
            .foregroundStyle(.secondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Color.secondary.opacity(0.15), in: Capsule())
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)
    }
}

// MARK: - Sort picker

/// Standard "Sort" menu for paginated review lists. The bound enum's
/// `rawValue` is shown as each menu item's label.
///
/// Example:
///     enum MySort: String, CaseIterable { case recent = "Most Recent" }
///     ReviewSortPicker(selection: $mySort)
struct ReviewSortPicker<Option>: View
    where Option: Hashable & CaseIterable & RawRepresentable, Option.RawValue == String {

    @Binding var selection: Option

    var body: some View {
        HStack {
            Label("Sort", systemImage: "arrow.up.arrow.down")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
            Picker("", selection: $selection) {
                ForEach(Array(Option.allCases), id: \.self) { option in
                    Text(option.rawValue).tag(option)
                }
            }
            .pickerStyle(.menu)
        }
    }
}

// MARK: - Pagination helpers

/// Stateless math shared by the carousel and its callers. Callers use
/// `pageCount(for:pageSize:)` to decide whether to render chevrons.
enum ReviewPagination {
    /// Per-card layout height used to compute the carousel's outer frame.
    /// Bumped from 220 → 260 when emoji reactions were added — `ReviewCard`
    /// reads from this same constant so the carousel and the cards stay
    /// perfectly in sync.
    static let cardHeight: CGFloat = 260

    static func chunkReviews(_ reviews: [Review], pageSize: Int) -> [[Review]] {
        guard pageSize > 0 else { return reviews.isEmpty ? [] : [reviews] }
        var chunks: [[Review]] = []
        for i in stride(from: 0, to: reviews.count, by: pageSize) {
            chunks.append(Array(reviews[i..<min(i + pageSize, reviews.count)]))
        }
        return chunks
    }

    static func pageCount(for reviewCount: Int, pageSize: Int) -> Int {
        guard reviewCount > 0, pageSize > 0 else { return 0 }
        return Int(ceil(Double(reviewCount) / Double(pageSize)))
    }

    /// The TabView needs a concrete height since its content is laid out
    /// page-by-page. We size for the tallest page (typically the first
    /// full page) and add a small buffer.
    static func carouselHeight(for reviews: [Review], pageSize: Int) -> CGFloat {
        let pages = chunkReviews(reviews, pageSize: pageSize)
        let spacing: CGFloat = 8
        let buffer: CGFloat = 48
        var maxHeight: CGFloat = 0
        for page in pages {
            let count = page.count
            let h = CGFloat(count) * cardHeight + CGFloat(max(0, count - 1)) * spacing + buffer
            maxHeight = max(maxHeight, h)
        }
        return maxHeight
    }
}
