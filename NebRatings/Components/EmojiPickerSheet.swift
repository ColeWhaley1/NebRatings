//
//  EmojiPickerSheet.swift
//  NebRatings
//
//  Hidden `UITextField` that exposes the system emoji keyboard on demand.
//  Used by `ReactionsBar` to let the user pick *any* emoji without a sheet —
//  the picker button asks the controller to focus the field directly via
//  `becomeFirstResponder()`. No SwiftUI state-propagation latency, no
//  intermediate sheet.
//
//  The file name still says "Sheet" for legacy reasons — the sheet was
//  removed in favor of an inline-focusable capture field.
//

import SwiftUI
import UIKit
import Combine  // for ObservableObject (used by EmojiPickerController)

// MARK: - UIKit-bridged emoji-only text field

/// `UITextField` subclass that pins its input mode to the emoji keyboard
/// so the user can't accidentally swap to a regular keyboard via the
/// globe key.
private final class EmojiInputTextField: UITextField {
    override var textInputContextIdentifier: String? { "" }

    override var textInputMode: UITextInputMode? {
        for mode in UITextInputMode.activeInputModes where mode.primaryLanguage == "emoji" {
            return mode
        }
        return super.textInputMode
    }
}

// MARK: - Focus controller

/// Bridges the SwiftUI side (a tap on the picker button) to the UIKit
/// side (the actual `UITextField` that owns the emoji keyboard). The
/// controller holds a weak reference to the field that the
/// `EmojiCaptureField` representable populates in `makeUIView`. Calling
/// `focus()` calls `becomeFirstResponder()` directly — no `@Binding`
/// propagation, no `updateUIView` round-trip, no race with SwiftUI
/// optimization that skips the update.
@MainActor
final class EmojiPickerController: ObservableObject {
    fileprivate weak var field: UITextField?

    func focus() {
        attemptFocus(retriesRemaining: 5)
    }

    /// `becomeFirstResponder()` returns `false` (and the keyboard never appears)
    /// if the field isn't in a window yet — which happens on the very first tap
    /// when SwiftUI hasn't finished installing the hidden capture field's
    /// `.background` into the hierarchy. That was the bug where the keyboard only
    /// showed up after a *second* interaction forced a layout pass. Retrying
    /// across a few runloop ticks lets the field settle into the window so the
    /// first tap reliably summons the keyboard.
    private func attemptFocus(retriesRemaining: Int) {
        if let field, field.window != nil, field.becomeFirstResponder() {
            return
        }
        guard retriesRemaining > 0 else { return }
        DispatchQueue.main.async { [weak self] in
            self?.attemptFocus(retriesRemaining: retriesRemaining - 1)
        }
    }
}

// MARK: - Capture field

/// Hidden capture field. Drop one anywhere in your view tree (size it 1×1pt
/// with low opacity) and call `controller.focus()` to summon the emoji
/// keyboard. Capturing a single emoji calls `onCapture(_:)` and resigns
/// first responder.
struct EmojiCaptureField: UIViewRepresentable {
    let controller: EmojiPickerController
    let onCapture: (String) -> Void

    func makeUIView(context: Context) -> UITextField {
        let field = EmojiInputTextField()
        field.delegate = context.coordinator
        field.tintColor = .clear   // hide caret in case field becomes visible
        field.autocorrectionType = .no
        field.spellCheckingType = .no

        // Toolbar above the keyboard with a Cancel button — without it the
        // only way to dismiss the keyboard would be to actually pick an
        // emoji, leaving users who change their mind stuck.
        let toolbar = UIToolbar()
        toolbar.sizeToFit()
        let flex = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
        let cancel = UIBarButtonItem(
            barButtonSystemItem: .cancel,
            target: context.coordinator,
            action: #selector(Coordinator.cancelTapped)
        )
        toolbar.items = [flex, cancel]
        field.inputAccessoryView = toolbar

        // Wire the controller so the SwiftUI side can directly focus us.
        controller.field = field
        context.coordinator.field = field

        return field
    }

    func updateUIView(_ uiView: UITextField, context: Context) {
        // Intentionally a no-op. Focus is driven by the controller, not by
        // a binding-triggered update — that was the broken mechanism that
        // made the keyboard only appear after the *second* state change.
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onCapture: onCapture)
    }

    final class Coordinator: NSObject, UITextFieldDelegate {
        weak var field: UITextField?
        let onCapture: (String) -> Void

        init(onCapture: @escaping (String) -> Void) {
            self.onCapture = onCapture
        }

        func textField(_ textField: UITextField,
                       shouldChangeCharactersIn range: NSRange,
                       replacementString string: String) -> Bool {
            let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return false }
            onCapture(trimmed)
            // Single emoji = single capture. Auto-dismiss the keyboard.
            textField.resignFirstResponder()
            return false
        }

        @objc func cancelTapped() {
            field?.resignFirstResponder()
        }
    }
}
