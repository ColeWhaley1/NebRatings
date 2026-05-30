//
//  AvatarView.swift
//  NebRatings
//

import SwiftUI

struct AvatarView: View {
    let emoji: String?
    var size: CGFloat = 56

    init(emoji: String?, size: CGFloat = 56) {
        self.emoji = emoji
        self.size = size
    }

    var body: some View {
        Group {
            if let emoji, !emoji.isEmpty {
                ZStack {
                    Circle().fill(Avatar.backgroundColor(for: emoji))
                    Text(emoji)
                        .font(.system(size: size * 0.55))
                }
                .frame(width: size, height: size)
            } else {
                ZStack {
                    Circle().fill(Color.gray.opacity(0.25))
                    Image(systemName: "person.fill")
                        .font(.system(size: size * 0.5))
                        .foregroundStyle(.secondary)
                }
                .frame(width: size, height: size)
            }
        }
        .overlay(Circle().stroke(Color.primary.opacity(0.08), lineWidth: 1))
    }
}

#Preview {
    HStack(spacing: 16) {
        AvatarView(emoji: "👽", size: 80)
        AvatarView(emoji: "🦄", size: 80)
        AvatarView(emoji: nil, size: 80)
    }
    .padding()
}
