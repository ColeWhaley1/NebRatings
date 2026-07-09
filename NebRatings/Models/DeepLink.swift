//
//  DeepLink.swift
//  NebRatings
//
//  One deep-link layer for two transports:
//    • Custom scheme  nebratings://show/movie/27205   (works today, no
//      domain needed — great for testing via `xcrun simctl openurl`).
//    • Universal Links https://<domain>/show/movie/27205 (activated by
//      flipping `isUniversalLinkingEnabled` once the domain hosts an AASA
//      file — see UNIVERSAL_LINKS_SETUP.md).
//
//  Both transports parse to the same `DeepLink` and route through the same
//  handler in ContentView, so nothing downstream cares which was used.
//
//  URL shapes (transport-agnostic path):
//    show/{movie|tv}/{tmdbID}
//    user/{userID}
//

import Foundation

enum DeepLink: Hashable {
    case show(id: Int, category: Show.Category)
    case profile(userID: String)
    case list(id: String)
}

enum DeepLinkConfig {
    /// App custom scheme (registered in Info.plist → CFBundleURLTypes).
    static let customScheme = "nebratings"

    /// Public web domain for Universal Links.
    static let webDomain = "nebratings.com"

    /// Master switch for PUBLIC https share links across the app. When true,
    /// every share sheet carries a `https://nebratings.com/...` deep link.
    /// (Custom-scheme routing works regardless — this only governs the
    /// public links we hand out.) Set false if you ever need to pull them.
    static let isUniversalLinkingEnabled = true

    /// The app's public web home — used as the download-driving link in
    /// shares that aren't tied to one specific title (e.g. Watch Together).
    static var homeURL: URL? {
        guard isUniversalLinkingEnabled else { return nil }
        return URL(string: "https://\(webDomain)")
    }
}

enum DeepLinkParser {

    // MARK: Parsing (URL → DeepLink)

    static func parse(_ url: URL) -> DeepLink? {
        let scheme = url.scheme?.lowercased()
        let isCustom = scheme == DeepLinkConfig.customScheme
        let host = url.host?.lowercased()
        let isWeb = (scheme == "https" || scheme == "http")
            && (host == DeepLinkConfig.webDomain || host == "www.\(DeepLinkConfig.webDomain)")
        guard isCustom || isWeb else { return nil }

        let segments = normalizedSegments(from: url)
        guard let first = segments.first?.lowercased() else { return nil }

        switch first {
        case "show":
            // show / {movie|tv} / {tmdbID}
            guard segments.count >= 3,
                  let category = category(fromToken: segments[1]),
                  let id = Int(segments[2]) else { return nil }
            return .show(id: id, category: category)

        case "user", "profile":
            // user / {userID}
            guard segments.count >= 2, !segments[1].isEmpty else { return nil }
            return .profile(userID: segments[1])

        case "list":
            // list / {listID}
            guard segments.count >= 2, !segments[1].isEmpty else { return nil }
            return .list(id: segments[1])

        default:
            return nil
        }
    }

    // MARK: Generation (DeepLink → URL)

    /// Builds a URL for a link. `universal: true` → https web domain (for
    /// public sharing), `false` → custom scheme (for internal/testing).
    static func url(for link: DeepLink, universal: Bool) -> URL? {
        let path: String
        switch link {
        case .show(let id, let category):
            path = "show/\(token(for: category))/\(id)"
        case .profile(let userID):
            guard let encoded = userID.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) else { return nil }
            path = "user/\(encoded)"
        case .list(let listID):
            guard let encoded = listID.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) else { return nil }
            path = "list/\(encoded)"
        }

        if universal {
            return URL(string: "https://\(DeepLinkConfig.webDomain)/\(path)")
        } else {
            return URL(string: "\(DeepLinkConfig.customScheme)://\(path)")
        }
    }

    // MARK: Helpers

    /// Path segments, normalized across transports:
    ///   nebratings://show/movie/27205    → ["show", "movie", "27205"]
    ///   https://domain/show/movie/27205  → ["show", "movie", "27205"]
    /// (For the custom scheme, the first path element is parsed as `host`.)
    private static func normalizedSegments(from url: URL) -> [String] {
        var segments: [String] = []
        if url.scheme?.lowercased() == DeepLinkConfig.customScheme, let host = url.host, !host.isEmpty {
            segments.append(host)
        }
        segments += url.pathComponents.filter { $0 != "/" && !$0.isEmpty }
        return segments
    }

    /// URL token → category. Accepts several spellings; generation always
    /// emits the canonical "movie"/"tv".
    private static func category(fromToken token: String) -> Show.Category? {
        switch token.lowercased() {
        case "movie", "movies", "film": return .movie
        case "tv", "series", "show", "shows": return .series
        default: return nil
        }
    }

    private static func token(for category: Show.Category) -> String {
        category == .movie ? "movie" : "tv"
    }
}

extension DeepLink {
    /// Public, shareable https link for this destination — or nil when
    /// Universal Linking is switched off. Single source of truth for every
    /// share surface (see ShareService).
    var shareURL: URL? {
        guard DeepLinkConfig.isUniversalLinkingEnabled else { return nil }
        return DeepLinkParser.url(for: self, universal: true)
    }
}

/// Identifiable wrapper so a profile deep link can drive `.sheet(item:)`.
struct ProfileLinkTarget: Identifiable, Hashable {
    let userID: String
    var id: String { userID }
}
