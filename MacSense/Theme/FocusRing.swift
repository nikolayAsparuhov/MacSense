import SwiftUI

extension View {
    /// Suppresses macOS's default blue focus ring on Buttons. Our buttons
    /// already render their own visible state (gradient pills, sliding
    /// sidebar pill, glossy CTA) — the system ring on top of that fights
    /// the design. Applying `.focusable(false)` keeps the visual exactly
    /// as designed before AND after click; bordered buttons keep their
    /// border, borderless ones stay borderless.
    ///
    /// On macOS 14+ we prefer `focusEffectDisabled()` — same effect but
    /// keeps the button keyboard-accessible (focus is just visually
    /// invisible). Older targets fall back to disabling focus entirely,
    /// which is fine for our UI since every button is mouse-driven.
    func noFocusRing() -> some View {
        modifier(NoFocusRingModifier())
    }
}

private struct NoFocusRingModifier: ViewModifier {
    func body(content: Content) -> some View {
        if #available(macOS 14.0, *) {
            content.focusEffectDisabled()
        } else {
            content.focusable(false)
        }
    }
}
