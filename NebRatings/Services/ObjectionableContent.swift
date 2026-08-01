//
//  ObjectionableContent.swift
//  NebRatings
//
//  Client-side filter that blocks objectionable free-text (review comments,
//  usernames, bios) at submission time. This is the "method for filtering
//  objectionable content" required by App Store Review Guideline 1.2 for apps
//  with user-generated content.
//
//  Design: normalize the input to defeat trivial evasions (casing, leet-speak,
//  punctuation), split into tokens, and flag any token that exactly matches a
//  curated list of slurs and strong profanity (including common inflections).
//  Exact-token matching — rather than substring — deliberately avoids the
//  "Scunthorpe problem": "despicable", "cocktail", and "raccoon" are never
//  flagged, while "fuck", "sh1t", and slurs are.
//

import Foundation

enum ObjectionableContent {
    /// Normalized (lowercase, letters-only) banned tokens, including the common
    /// inflections we want to catch. Matched exactly against each input token.
    private static let bannedTokens: Set<String> = [
        // Slurs and hate terms + common plurals/inflections.
        "nigger", "niggers", "nigga", "niggas", "faggot", "faggots", "fag",
        "fags", "retard", "retards", "retarded", "chink", "chinks", "spic",
        "spics", "kike", "kikes", "tranny", "trannies", "coon", "coons",
        "gook", "gooks", "beaner", "beaners", "wetback", "wetbacks",
        // Strong profanity + common inflections.
        "fuck", "fucks", "fucking", "fucked", "fucker", "fuckers",
        "motherfucker", "motherfuckers", "fuckface", "fuckwit",
        "shit", "shits", "shitty", "shitting", "bullshit", "shithead",
        "bitch", "bitches", "bitching", "cunt", "cunts",
        "asshole", "assholes", "bastard", "bastards",
        "dickhead", "dick", "dicks", "pussy", "pussies",
        "whore", "whores", "slut", "sluts", "cock", "cocks"
    ]

    /// Reverse common leet substitutions so "sh1t" / "f@ck" still match.
    private static let leetMap: [Character: Character] = [
        "0": "o", "1": "i", "3": "e", "4": "a", "5": "s",
        "7": "t", "8": "b", "@": "a", "$": "s", "!": "i"
    ]

    /// True if the text contains objectionable language.
    static func isObjectionable(_ text: String) -> Bool {
        firstMatch(in: text) != nil
    }

    /// Returns the first banned token found (normalized), or nil. Exposed mainly
    /// so callers/tests can see *why* something was rejected.
    static func firstMatch(in text: String) -> String? {
        normalizedTokens(text).first { bannedTokens.contains($0) }
    }

    /// Lowercase, reverse leet, then split into letter-only tokens.
    private static func normalizedTokens(_ text: String) -> [String] {
        let mapped = text.lowercased().map { leetMap[$0] ?? $0 }
        var tokens: [String] = []
        var current = ""
        for ch in mapped {
            if ch.isLetter {
                current.append(ch)
            } else if !current.isEmpty {
                tokens.append(current)
                current = ""
            }
        }
        if !current.isEmpty { tokens.append(current) }
        return tokens
    }
}
