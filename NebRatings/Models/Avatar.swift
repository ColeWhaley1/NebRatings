//
//  Avatar.swift
//  NebRatings
//

import SwiftUI

enum Avatar {
    /// Fun/goofy emoji gallery. Users can also type any emoji from Apple's keyboard.
    static let presets: [String] = [
        "👽", "🤖", "👻", "🦄", "🐙", "🦖",
        "🌮", "🍕", "🔮", "🚀", "🪐", "🦑",
        "😎", "🤓", "🥸", "🤠", "👾", "🐲",
        "🦁", "🐸", "🐵", "🐧", "🦊", "🐳",
        "🍔", "🍩", "🌈", "🔥", "🌟", "🎮",
        "🍿", "👑", "💀", "🤡", "🎲", "🛸"
    ]

    private static let palette: [Color] = [
        Color(red: 0.85, green: 0.78, blue: 1.00), // lavender
        Color(red: 0.78, green: 0.95, blue: 1.00), // sky
        Color(red: 1.00, green: 0.82, blue: 0.87), // pink
        Color(red: 1.00, green: 0.90, blue: 0.74), // peach
        Color(red: 0.82, green: 0.97, blue: 0.86), // mint
        Color(red: 1.00, green: 0.96, blue: 0.74)  // butter
    ]

    /// Returns a stable pastel background for any emoji (presets use their slot,
    /// custom emojis are hashed into the palette so they still look colorful).
    static func backgroundColor(for emoji: String?) -> Color {
        guard let emoji, !emoji.isEmpty else { return Color.gray.opacity(0.25) }
        if let idx = presets.firstIndex(of: emoji) {
            return palette[idx % palette.count]
        }
        let hash = abs(emoji.unicodeScalars.reduce(0) { $0 &+ Int(truncatingIfNeeded: $1.value) })
        return palette[hash % palette.count]
    }

    static func randomPreset() -> String {
        presets.randomElement() ?? "👽"
    }
}

extension Character {
    /// True for emoji characters (used to validate custom emoji entry).
    var isEmojiCharacter: Bool {
        guard let scalar = unicodeScalars.first else { return false }
        // Multi-scalar graphemes (e.g. flags, skin tones) or scalars with emoji
        // presentation above the dingbat range count as emoji.
        return unicodeScalars.count > 1
            ? unicodeScalars.contains { $0.properties.isEmojiPresentation || $0.properties.isEmoji }
            : (scalar.properties.isEmojiPresentation || (scalar.properties.isEmoji && scalar.value > 0x238C))
    }
}
