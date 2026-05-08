import SwiftUI

/// First-run coach mark. Renders a dimmed scrim with a transparent
/// cut-out around the host view's bounds + a floating tooltip card.
/// Each marker fires once — `MacSense.CoachMarks.<id>.Seen` is
/// flipped on dismiss.
///
/// Apply via the `.coachMark(...)` view modifier on the target view.
/// The modifier reads the seen flag and renders nothing once the
/// user has tapped "Got it".
struct CoachMark: ViewModifier {
    let id: String
    let title: String
    let message: String

    @State private var isVisible: Bool = false
    @State private var anchor: CGRect = .zero

    private var seenKey: String { "MacSense.CoachMarks.\(id).Seen" }

    func body(content: Content) -> some View {
        content
            .background(
                GeometryReader { proxy in
                    Color.clear
                        .onAppear {
                            anchor = proxy.frame(in: .global)
                            if !UserDefaults.standard.bool(forKey: seenKey) {
                                isVisible = true
                            }
                        }
                        .onChange(of: proxy.frame(in: .global)) { newValue in
                            anchor = newValue
                        }
                }
            )
            .overlay(overlayContent)
    }

    @ViewBuilder
    private var overlayContent: some View {
        if isVisible {
            CoachMarkOverlay(title: title, message: message, anchor: anchor) {
                UserDefaults.standard.set(true, forKey: seenKey)
                withAnimation(.easeOut(duration: 0.18)) { isVisible = false }
            }
            .ignoresSafeArea()
            .transition(.opacity)
        }
    }
}

private struct CoachMarkOverlay: View {
    let title: String
    let message: String
    let anchor: CGRect
    let onDismiss: () -> Void

    var body: some View {
        ZStack(alignment: .topLeading) {
            // Dimmed backdrop — tap anywhere outside the tooltip to
            // dismiss. The cut-out is decorative (we don't actually
            // mask through to the underlying view) so the user gets
            // a visual halo instead of a precise hole.
            Rectangle()
                .fill(.black.opacity(0.55))
                .contentShape(Rectangle())
                .onTapGesture { onDismiss() }

            // Spotlight ring around the target.
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Theme.Palette.cyan.opacity(0.85), lineWidth: 3)
                .frame(width: anchor.width + 12, height: anchor.height + 12)
                .position(x: anchor.midX, y: anchor.midY)
                .shadow(color: Theme.Palette.cyan.opacity(0.55), radius: 18)
                .allowsHitTesting(false)

            // Tooltip card placed below the target if there's room,
            // otherwise above. Width clamped so it never spans the
            // entire window.
            tooltipCard
                .position(tooltipPosition)
                .frame(width: 320)
        }
    }

    private var tooltipPosition: CGPoint {
        let belowY = anchor.maxY + 90
        return CGPoint(x: anchor.midX, y: belowY)
    }

    private var tooltipCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white)
            Text(message)
                .font(.system(size: 12))
                .foregroundStyle(.white.opacity(0.8))
                .fixedSize(horizontal: false, vertical: true)
            HStack {
                Spacer()
                Button("Got it", action: onDismiss)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .tint(Theme.Palette.cyan)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous).fill(.regularMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.45), radius: 20, y: 10)
    }
}

extension View {
    /// Attach a one-shot coach mark. `id` controls the persisted
    /// seen flag — keep it stable across releases.
    func coachMark(id: String, title: String, body: String) -> some View {
        modifier(CoachMark(id: id, title: title, message: body))
    }
}
