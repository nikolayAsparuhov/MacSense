import SwiftUI

/// Centralized animation curves for MacSense.
///
/// Goal: every state change feels smooth and intentional. Spring curves
/// dominate (CleanMyMac-style) with a few short eases for micro-feedback.
enum AppAnimation {
    /// Default for content swaps between sections in the detail pane.
    static let sectionTransition: Animation = .spring(response: 0.45, dampingFraction: 0.82)

    /// Hover / press feedback on interactive cards.
    static let cardPress: Animation = .spring(response: 0.28, dampingFraction: 0.7)

    /// Gauge / chart value updates — smooth without lagging.
    static let value: Animation = .spring(response: 0.5, dampingFraction: 0.85)

    /// Sidebar selection highlight.
    static let sidebar: Animation = .spring(response: 0.35, dampingFraction: 0.78)

    /// Brief micro-fade for chrome elements (status pills, badge counts).
    static let chrome: Animation = .easeInOut(duration: 0.18)
}

/// Vertical slide + fade transition used everywhere content swaps —
/// section switches, two-state hero/detail toggles, sub-tab swaps.
///
/// Pattern: outgoing fades + slides UP + scales down slightly (recedes).
/// Incoming fades + slides up from below + scales up. Consistent
/// vertical directionality reads as a continuous lift; the scale adds
/// liveliness (UX principle 2 — scale pairs with fade).
extension AnyTransition {
    static var sectionSwap: AnyTransition {
        .asymmetric(
            insertion: .move(edge: .bottom)
                .combined(with: .opacity)
                .combined(with: .scale(scale: 0.97, anchor: .center)),
            removal: .move(edge: .top)
                .combined(with: .opacity)
                .combined(with: .scale(scale: 0.97, anchor: .center))
        )
    }

    /// Same vertical lift, tighter — used for in-section swaps (hero →
    /// detail within Cleanup, etc.).
    static var contentLift: AnyTransition {
        .asymmetric(
            insertion: .move(edge: .bottom)
                .combined(with: .opacity)
                .combined(with: .scale(scale: 0.96, anchor: .center)),
            removal: .move(edge: .top)
                .combined(with: .opacity)
                .combined(with: .scale(scale: 0.96, anchor: .center))
        )
    }
}

/// Cascading appear — staggers child entry so primary content lands
/// before secondary (UX principle 5 — prioritize, order, and group).
/// Combines fade + short vertical slide + tiny scale (principles 1 + 2).
///
/// Stamp on each row in a list with an index-derived delay, clamped so
/// long lists don't drag (principle 4 — balance speed).
struct CascadeAppear: ViewModifier {
    let delay: Double
    @State private var visible = false

    func body(content: Content) -> some View {
        content
            .opacity(visible ? 1 : 0)
            .offset(y: visible ? 0 : 10)
            .scaleEffect(visible ? 1.0 : 0.97, anchor: .center)
            .onAppear {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.85).delay(delay)) {
                    visible = true
                }
            }
    }
}

extension View {
    /// Cascade by index. 35ms per row, capped at 450ms total so long
    /// lists stay snappy.
    func cascadeAppear(index: Int, base: Double = 0.05, step: Double = 0.035, cap: Double = 0.45) -> some View {
        modifier(CascadeAppear(delay: min(base + Double(index) * step, cap)))
    }

    /// Fixed-delay cascade — for non-list sequences (header → body →
    /// footer of a single panel).
    func cascadeAppear(delay: Double) -> some View {
        modifier(CascadeAppear(delay: delay))
    }
}
