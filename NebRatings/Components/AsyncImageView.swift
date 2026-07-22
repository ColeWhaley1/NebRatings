//
//  AsyncImageView.swift
//  NebRatings
//
//  Cache-backed async image. If the image is already decoded (it usually is,
//  thanks to prefetching), it paints instantly with no flicker. Otherwise it
//  shows a neutral placeholder — not a spinner — and fades the image in.
//  Backed by ImageCache so scrolling back to a poster is instant.
//

import SwiftUI

struct AsyncImageView: View {
    let urlString: String?

    @State private var image: UIImage?
    @State private var loadedURL: String?

    init(urlString: String?) {
        self.urlString = urlString
    }

    var body: some View {
        ZStack {
            // Calm placeholder tuned to the dark UI — no spinner "pop".
            Color.white.opacity(0.06)
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .transition(.opacity)
            }
        }
        .clipped()
        .task(id: urlString) { await load() }
    }

    private func load() async {
        guard let urlString, !urlString.isEmpty, let url = URL(string: urlString) else {
            image = nil
            return
        }
        // Already showing the right image (view reused with same URL).
        if loadedURL == urlString, image != nil { return }

        // Instant path: decoded image already in memory.
        if let hit = ImageCache.shared.cachedImage(for: url) {
            image = hit
            loadedURL = urlString
            return
        }

        // Reset while a genuinely new URL loads, then fade in.
        image = nil
        if let loaded = await ImageCache.shared.image(for: url), self.urlString == urlString {
            withAnimation(.easeOut(duration: 0.22)) { image = loaded }
            loadedURL = urlString
        }
    }
}
