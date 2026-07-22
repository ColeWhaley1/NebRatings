//
//  ShowDetailTrailersView.swift
//  NebRatings
//
//  "Trailers" section for ShowDetailView. Horizontal strip of YouTube
//  thumbnails with a play badge; tapping opens an in-app embedded player
//  sheet with an "open in YouTube" escape hatch. Callers hide the whole
//  section when `trailers` is empty (TMDB has no YouTube trailers).
//

import SwiftUI
import WebKit

struct ShowDetailTrailersView: View {
    let trailers: [Trailer]

    @State private var playingTrailer: Trailer?

    /// 16:9 thumbnail card sized so ~1.5 cards are visible, hinting that
    /// the strip scrolls when there are more trailers.
    private let cardWidth: CGFloat = 240
    private var cardHeight: CGFloat { cardWidth * 9 / 16 }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Trailers")
                .font(.title3.bold())
                .foregroundStyle(.primary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(trailers) { trailer in
                        trailerCard(trailer)
                    }
                }
            }
        }
        .sheet(item: $playingTrailer) { trailer in
            TrailerPlayerSheet(trailer: trailer)
        }
    }

    private func trailerCard(_ trailer: Trailer) -> some View {
        Button {
            playingTrailer = trailer
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                ZStack {
                    AsyncImageView(urlString: trailer.thumbnailURL)
                        .frame(width: cardWidth, height: cardHeight)
                        .clipShape(RoundedRectangle(cornerRadius: 12))

                    // Play badge — slight dim behind so it reads on bright frames.
                    Image(systemName: "play.circle.fill")
                        .font(.system(size: 44))
                        .foregroundStyle(.white, .black.opacity(0.55))
                        .shadow(radius: 6)
                }

                Text(trailer.name)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .frame(width: cardWidth, alignment: .leading)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Play trailer: \(trailer.name)")
    }
}

// MARK: - Player sheet

/// Embedded YouTube playback via WKWebView. Some videos disallow embedding —
/// the toolbar's YouTube button is the always-available fallback, and if the
/// embed page itself fails to load we swap in a full-size fallback prompt.
private struct TrailerPlayerSheet: View {
    let trailer: Trailer

    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @State private var embedFailed = false

    var body: some View {
        NavigationStack {
            Group {
                if embedFailed {
                    fallbackView
                } else {
                    YouTubeEmbedView(youtubeKey: trailer.youtubeKey, onFail: { embedFailed = true })
                        .ignoresSafeArea(edges: .bottom)
                }
            }
            .navigationTitle(trailer.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    if let watchURL = trailer.watchURL {
                        Button {
                            openURL(watchURL)
                        } label: {
                            Label("Open in YouTube", systemImage: "arrow.up.right.square")
                        }
                    }
                }
            }
            .background(Color.black)
        }
    }

    private var fallbackView: some View {
        VStack(spacing: 16) {
            Image(systemName: "play.slash")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text("This trailer can't be played in the app.")
                .foregroundStyle(.secondary)
            if let watchURL = trailer.watchURL {
                Button {
                    openURL(watchURL)
                } label: {
                    Label("Watch on YouTube", systemImage: "play.rectangle.fill")
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// In-app YouTube playback via the *watch page*, not the iframe embed.
///
/// Why not the embed player: YouTube's embed now hard-requires an HTTP
/// Referer, and WKWebView never sends one for locally-injected pages
/// (WebKit bug 169846) — meta referrer tags, `referrerpolicy` attributes,
/// `origin` playerVars, and custom user agents are all confirmed dead ends
/// on iOS. Every video fails with error 152/153 regardless of its own
/// embed permissions. Loading the mobile watch page as a normal top-level
/// navigation sidesteps the entire referer check (it's YouTube's own site,
/// not an embed), so trailers play in-app reliably — the same way they
/// would in Safari.
private struct YouTubeEmbedView: UIViewRepresentable {
    let youtubeKey: String
    let onFail: () -> Void

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.isOpaque = false
        webView.backgroundColor = .black
        // Safari-equivalent UA so YouTube serves its full mobile site
        // (unknown UAs get a degraded page).
        webView.customUserAgent = "Mozilla/5.0 (iPhone; CPU iPhone OS 18_1 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.1 Mobile/15E148 Safari/604.1"

        if let url = URL(string: "https://m.youtube.com/watch?v=\(youtubeKey)&autoplay=1&playsinline=1") {
            webView.load(URLRequest(url: url))
        } else {
            onFail()
        }
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onFail: onFail)
    }

    final class Coordinator: NSObject, WKNavigationDelegate {
        let onFail: () -> Void

        init(onFail: @escaping () -> Void) {
            self.onFail = onFail
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            onFail()
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            onFail()
        }
    }
}

// MARK: - Previews

#Preview("Trailers strip") {
    ShowDetailTrailersView(trailers: [
        Trailer(id: "1", youtubeKey: "dQw4w9WgXcQ", name: "Official Trailer", type: "Trailer", isOfficial: true),
        Trailer(id: "2", youtubeKey: "9bZkp7q19f0", name: "Teaser: First Look", type: "Teaser", isOfficial: true),
        Trailer(id: "3", youtubeKey: "kJQP7kiw5Fk", name: "International Trailer", type: "Trailer", isOfficial: false)
    ])
    .padding()
    .background(Color(.systemGroupedBackground))
}
