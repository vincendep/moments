import UIKit

/// Hides the keyboard when tapping anywhere outside a text field, sheets included (they share the window).
/// The tap is only observed: buttons, toggles and rows still get it.
final class KeyboardDismissal: NSObject, UIGestureRecognizerDelegate {
    private static let shared = KeyboardDismissal()

    static func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }

    /// Adds the tap to every window once; safe to call again.
    static func install() {
        for case let scene as UIWindowScene in UIApplication.shared.connectedScenes {
            for window in scene.windows
            where !(window.gestureRecognizers ?? []).contains(where: { $0.delegate === shared }) {
                let tap = UITapGestureRecognizer(target: shared, action: #selector(tapped))
                tap.cancelsTouchesInView = false
                tap.delegate = shared
                window.addGestureRecognizer(tap)
            }
        }
    }

    @objc private func tapped() { Self.hideKeyboard() }

    /// Taps on a text field or editor move the focus as usual instead.
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        var view = touch.view
        while let v = view {
            if v is UITextField || v is UITextView { return false }
            view = v.superview
        }
        return true
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                           shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool { true }
}
