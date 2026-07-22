//
//  PressableButtonStyle.swift
//  NebRatings
//
//  Shared "squishy" press feedback: the label springs down slightly while
//  pressed and bounces back on release. Applied to tappable cards (mood
//  chips, poster cards) so browsing feels tactile instead of static.
//

import SwiftUI

struct PressableButtonStyle: ButtonStyle {
    /// How far the label shrinks while pressed.
    var pressedScale: CGFloat = 0.93

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? pressedScale : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.55), value: configuration.isPressed)
    }
}
