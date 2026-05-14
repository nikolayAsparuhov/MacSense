import SwiftUI

/// First-run coach mark. Renders a dimmed full-screen scrim with a
/// centered tooltip card. Each marker fires once —
/// `MacSense.CoachMarks.<id>.Seen` is flipped on dismiss.
///
/// Apply via `.coachMark(id:title:body:)` on the target view.
/// The modifier reads the seen flag and renders nothing once the
/// user has tapped "Got it".
///
/// v1 deliberately uses a centered modal layout instead of a
/// position-anchored spotlight ring — anchoring needs a window-level
/// overlay to align the ring with global coordinates, which would
/// require lifting the renderer up to `MainWindow`. The current shape
/// is enough to introduce a feature without the layout bugs that came
/// with mixing global anchors and a view-local overlay.
struct CoachMark: ViewModifier {
    let id: String
    let title: String
    let message: String

    @State private var isVisible: Bool = false

    private var seenKey: String { "MacSense.CoachMarks.\(id).Seen" }

    func body(content: Content) -> some View {
        content
            .onAppear {
                if !UserDefaults.standard.bool(forKey: seenKey) {
                    // Tiny defer so the appearance lands after the
                    // section's transition settles — otherwise the
                    // mark briefly draws over a half-rendered view
                    // on first launch.
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                        if !UserDefaults.standard.bool(forKey: seenKey) {
                            withAnimation(.easeIn(duration: 0.18)) {
                                isVisible = true
                            }
                        }
                    }
                }
            }
            .overlay {
                if isVisible {
                    overlay
                        .transition(.opacity)
                }
            }
    }

    private var overlay: some View {
        ZStack {
            Rectangle()
                .fill(.black.opacity(0.55))
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture(perform: dismiss)

            VStack(alignment: .leading, spacing: 12) {
                Text(title)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.white)
                Text(message)
                    .font(.system(size: 13))
                    .foregroundStyle(.white.opacity(0.85))
                    .fixedSize(horizontal: false, vertical: true)
                HStack {
                    Spacer()
                    Button(Localization.shared.t(.commonGotIt), action: dismiss)
                        .buttonStyle(.borderedProminent)
                        .controlSize(.regular)
                        .tint(Theme.Palette.cyan)
                }
            }
            .padding(20)
            .frame(width: 360)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous).fill(.regularMaterial)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.45), radius: 24, y: 12)
        }
    }

    private func dismiss() {
        UserDefaults.standard.set(true, forKey: seenKey)
        withAnimation(.easeOut(duration: 0.18)) { isVisible = false }
    }
}

extension View {
    /// Attach a one-shot coach mark. `id` controls the persisted
    /// seen flag — keep it stable across releases.
    func coachMark(id: String, title: String, body: String) -> some View {
        modifier(CoachMark(id: id, title: title, message: body))
    }
}
