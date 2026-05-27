//
//  Avatar.swift
//  NebRatings
//

import SwiftUI

enum Avatar {
    static let presets: [String] = [
        "👽", "🤖", "👻", "🦄", "🐙", "🦖",
        "🌮", "🍕", "🔮", "🚀", "🪐", "🦑"
    ]

    private static let palette: [Color] = [
        Color(red: 0.85, green: 0.78, blue: 1.00), // lavender
        Color(red: 0.78, green: 0.95, blue: 1.00), // sky
        Color(red: 1.00, green: 0.82, blue: 0.87), // pink
        Color(red: 1.00, green: 0.90, blue: 0.74), // peach
        Color(red: 0.82, green: 0.97, blue: 0.86), // mint
        Color(red: 1.00, green: 0.96, blue: 0.74)  // butter
    ]

    static func backgroundColor(for emoji: String?) -> Color {
        guard let emoji, let idx = presets.firstIndex(of: emoji) else {
            return Color.gray.opacity(0.25)
        }
        return palette[idx % palette.count]
    }

    static func randomPreset() -> String {
        presets.randomElement() ?? "👽"
    }
}
