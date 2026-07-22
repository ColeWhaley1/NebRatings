//
//  CriticGaugeView.swift
//  NebRatings
//

import SwiftUI

struct CriticGaugeView: View {
    /// Average of (user's nebRating − TMDB audience rating). nil while loading.
    let delta: Double?
    let sampleSize: Int
    let isLoading: Bool

    private enum Harshness {
        case marshmallow, soft, balanced, tough, savage

        static func from(delta: Double) -> Harshness {
            if delta > 1.5 { return .marshmallow }
            if delta > 0.5 { return .soft }
            if delta >= -0.5 { return .balanced }
            if delta >= -1.5 { return .tough }
            return .savage
        }

        var label: String {
            switch self {
            case .marshmallow: return "Marshmallow"
            case .soft:        return "Soft Touch"
            case .balanced:    return "Balanced"
            case .tough:       return "Tough Critic"
            case .savage:      return "Savage"
            }
        }

        var emoji: String {
            switch self {
            case .marshmallow: return "🥺"
            case .soft:        return "😊"
            case .balanced:    return "⚖️"
            case .tough:       return "🧐"
            case .savage:      return "💀"
            }
        }

        var color: Color {
            switch self {
            case .marshmallow: return Color(red: 0.93, green: 0.40, blue: 0.65)
            case .soft:        return Color(red: 0.18, green: 0.72, blue: 0.45)
            case .balanced:    return Color(red: 0.30, green: 0.55, blue: 0.92)
            case .tough:       return Color(red: 0.95, green: 0.55, blue: 0.10)
            case .savage:      return Color(red: 0.86, green: 0.20, blue: 0.20)
            }
        }

        /// Normalized position on the gauge: 0 = most generous, 1 = most savage.
        var position: Double {
            switch self {
            case .marshmallow: return 0.05
            case .soft:        return 0.27
            case .balanced:    return 0.5
            case .tough:       return 0.73
            case .savage:      return 0.95
            }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "scope")
                    .foregroundStyle(.secondary)
                Text("Critic Harshness")
                    .font(.subheadline.bold())
                    .foregroundStyle(.secondary)
                Spacer()
                if !isLoading, sampleSize > 0 {
                    Text("\(sampleSize) compared")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }

            if isLoading {
                HStack {
                    ProgressView().scaleEffect(0.8)
                    Text("Measuring…")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, 16)
            } else if let delta {
                let harshness = Harshness.from(delta: delta)
                gaugeBody(harshness: harshness, delta: delta)
            } else {
                Text("Not enough overlap with TMDB ratings yet.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 12)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.gray.opacity(0.08))
        )
    }

    @ViewBuilder
    private func gaugeBody(harshness: Harshness, delta: Double) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            // Big label so the meaning is unmistakable
            HStack(spacing: 8) {
                Text(harshness.emoji)
                    .font(.system(size: 30))
                Text(harshness.label)
                    .font(.title3.bold())
                    .foregroundStyle(harshness.color)
                Spacer()
                Text(deltaString(delta))
                    .font(.caption.bold().monospacedDigit())
                    .foregroundStyle(harshness.color)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(harshness.color.opacity(0.15), in: Capsule())
            }

            // Gradient gauge bar with a position marker
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    LinearGradient(
                        colors: [
                            Harshness.marshmallow.color,
                            Harshness.soft.color,
                            Harshness.balanced.color,
                            Harshness.tough.color,
                            Harshness.savage.color
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .clipShape(Capsule())

                    Circle()
                        .fill(.white)
                        .frame(width: 16, height: 16)
                        .overlay(Circle().stroke(harshness.color, lineWidth: 3))
                        .shadow(color: .black.opacity(0.15), radius: 2, y: 1)
                        .offset(x: max(0, min(geo.size.width - 16, geo.size.width * harshness.position - 8)))
                }
            }
            .frame(height: 16)

            HStack {
                Text("Generous")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("Harsh")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func deltaString(_ delta: Double) -> String {
        let sign = delta >= 0 ? "+" : ""
        return "\(sign)\(String(format: "%.1f", delta)) vs TMDB"
    }
}

#Preview {
    VStack(spacing: 16) {
        CriticGaugeView(delta: 2.3, sampleSize: 12, isLoading: false)
        CriticGaugeView(delta: 0.6, sampleSize: 8, isLoading: false)
        CriticGaugeView(delta: -0.1, sampleSize: 20, isLoading: false)
        CriticGaugeView(delta: -1.0, sampleSize: 14, isLoading: false)
        CriticGaugeView(delta: -2.5, sampleSize: 9, isLoading: false)
        CriticGaugeView(delta: nil, sampleSize: 0, isLoading: true)
    }
    .padding()
}
