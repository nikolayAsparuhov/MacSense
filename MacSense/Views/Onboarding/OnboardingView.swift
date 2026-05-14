import SwiftUI
import AppKit

/// First-launch onboarding. CleanMyMac-style two-phase flow:
///   1. Request Full Disk Access — explain why, big CTA, Skip option.
///   2. Granted — success state with Begin button.
///
/// We poll FDA every second while the request screen is visible; as soon
/// as the user grants it (in System Settings) the view animates to the
/// success state automatically.
struct OnboardingView: View {
    @Binding var isComplete: Bool
    @State private var phase: Phase
    @State private var poller: Timer?

    enum Phase: Equatable {
        case request
        case granted
    }

    init(isComplete: Binding<Bool>) {
        self._isComplete = isComplete
        // If FDA is already granted on first run, skip straight to success.
        let granted = FullDiskAccessManager.shared.hasFullDiskAccess
        self._phase = State(initialValue: granted ? .granted : .request)
    }

    var body: some View {
        ZStack {
            backgroundLayer

            HStack(alignment: .center, spacing: 60) {
                leftIllustration
                    .frame(maxWidth: .infinity)

                rightCopy
                    .frame(maxWidth: .infinity)
            }
            .padding(.horizontal, 80)
            .padding(.vertical, 60)

            // Bottom-right action area, anchored separately so the layout
            // matches CleanMyMac's onboarding screens precisely.
            VStack {
                Spacer()
                HStack(spacing: 14) {
                    Spacer()
                    if phase == .request {
                        Button(Localization.shared.t(.commonSkipForNow)) {
                            finish()
                        }
                        .buttonStyle(.plain)
                        .noFocusRing()
                        .foregroundStyle(.white)
                        .font(.system(size: 14, weight: .semibold))
                    }

                    Button {
                        if phase == .request {
                            FullDiskAccessManager.shared.openFullDiskAccessSettings()
                        } else {
                            finish()
                        }
                    } label: {
                        Text(phase == .request ? Localization.shared.t(.onboardingGrantButton) : Localization.shared.t(.onboardingBeginButton))
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                            .padding(.vertical, 14)
                            .padding(.horizontal, 28)
                            .background(Capsule().fill(Theme.brandGradient))
                            .shadow(color: Theme.Palette.cyan.opacity(0.55),
                                    radius: 22, x: 0, y: 10)
                    }
                    .buttonStyle(.plain)
                    .noFocusRing()
                }
                .padding(.trailing, 60)
                .padding(.bottom, 50)
            }
        }
        .frame(minWidth: 1000, minHeight: 640)
        .onAppear { startPolling() }
        .onDisappear { stopPolling() }
        .preferredColorScheme(.dark)
    }

    // MARK: - Left side: illustration + floating pills

    private var leftIllustration: some View {
        ZStack {
            VStack(alignment: .leading, spacing: 14) {
                pill(Localization.shared.t(.onboardingPillProtection))
                HStack(spacing: 14) {
                    pill(Localization.shared.t(.onboardingPillFindMoreJunk))
                    pill(Localization.shared.t(.onboardingPillManage))
                }
                Spacer().frame(height: 30)
                driveIllustration
                    .frame(width: 360, height: 320)
            }
        }
    }

    private func pill(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(.white.opacity(0.9))
            .padding(.vertical, 9)
            .padding(.horizontal, 16)
            .background(
                Capsule()
                    .fill(.ultraThinMaterial)
                    .overlay(Capsule().strokeBorder(Color.white.opacity(0.10), lineWidth: 1))
            )
            .shadow(color: .black.opacity(0.3), radius: 12, x: 0, y: 6)
    }

    // CleanMyMac uses a 3D-rendered drive with a checkmark badge. Here we
    // fake the 3D look with stacked gradient rounded rectangles + sparkle
    // SF Symbols. Good enough at this size; replace with a proper render
    // if a designer ships one.
    private var driveIllustration: some View {
        ZStack {
            driveBody

            // Sparkles in front of the drive.
            Image(systemName: "sparkles")
                .font(.system(size: 38, weight: .bold))
                .foregroundStyle(LinearGradient(
                    colors: [.white, Theme.Palette.cyan],
                    startPoint: .top, endPoint: .bottom))
                .offset(x: -30, y: 50)
                .shadow(color: .white.opacity(0.6), radius: 8)

            // Status badge overlay — blue check during request, green on granted.
            statusBadge
                .frame(width: 110, height: 110)
                .offset(x: 90, y: -40)
        }
    }

    private var driveBody: some View {
        // Two-tone rounded rectangle that reads as a stylized external drive.
        ZStack(alignment: .bottom) {
            RoundedRectangle(cornerRadius: 36, style: .continuous)
                .fill(LinearGradient(
                    colors: [Theme.Palette.cyan, Theme.Palette.azure],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                ))
                .overlay(
                    RoundedRectangle(cornerRadius: 36, style: .continuous)
                        .strokeBorder(.white.opacity(0.1), lineWidth: 1)
                )
                .shadow(color: Theme.Palette.azure.opacity(0.45),
                        radius: 30, x: 0, y: 16)

            Capsule()
                .fill(Color.black.opacity(0.4))
                .frame(width: 60, height: 6)
                .padding(.bottom, 24)
        }
    }

    @ViewBuilder
    private var statusBadge: some View {
        switch phase {
        case .request:
            ZStack {
                Circle()
                    .fill(LinearGradient(
                        colors: [Theme.Palette.cyan, Theme.Palette.azure],
                        startPoint: .top, endPoint: .bottom))
                Image(systemName: "checkmark")
                    .font(.system(size: 44, weight: .bold))
                    .foregroundStyle(.white)
                    .shadow(color: .white.opacity(0.7), radius: 6)
            }
            .shadow(color: Theme.Palette.azure.opacity(0.6), radius: 24, x: 0, y: 8)
            .transition(.scale.combined(with: .opacity))

        case .granted:
            ZStack {
                Circle()
                    .fill(LinearGradient(
                        colors: [Color(red: 0.20, green: 0.85, blue: 0.55),
                                 Color(red: 0.10, green: 0.65, blue: 0.45)],
                        startPoint: .top, endPoint: .bottom))
                Image(systemName: "checkmark")
                    .font(.system(size: 44, weight: .bold))
                    .foregroundStyle(.white)
                    .shadow(color: .white.opacity(0.7), radius: 6)
            }
            .shadow(color: Color(red: 0.20, green: 0.85, blue: 0.55).opacity(0.6), radius: 28, x: 0, y: 8)
            .transition(.scale.combined(with: .opacity))
        }
    }

    // MARK: - Right side: copy

    private var rightCopy: some View {
        VStack(alignment: .leading, spacing: 18) {
            Group {
                if phase == .request {
                    Text(Localization.shared.t(.onboardingGrantFDA))
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                } else {
                    Text(Localization.shared.t(.onboardingGrantedFDA))
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                }
            }
            .transition(.opacity)

            Text(phase == .request
                 ? Localization.shared.t(.onboardingRequestBody)
                 : Localization.shared.t(.onboardingGrantedBody))
                .font(.system(size: 16, weight: .regular))
                .foregroundStyle(.white.opacity(0.65))
                .lineSpacing(4)
                .frame(maxWidth: 460, alignment: .leading)
                .transition(.opacity)
        }
    }

    // MARK: - Background

    private var backgroundLayer: some View {
        ZStack {
            // Slate-charcoal radial — Forest Steel's onboarding backdrop.
            RadialGradient(
                colors: [
                    Theme.Palette.surfaceHi,
                    Theme.Palette.surfaceDeep,
                ],
                center: .center, startRadius: 50, endRadius: 900
            )
            .ignoresSafeArea()

            // Faint sage wash from the bottom-right where the CTA sits.
            LinearGradient(
                colors: [Color.clear, Theme.Palette.cyan.opacity(0.12)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
        }
    }

    // MARK: - FDA polling

    private func startPolling() {
        // Cheap timer — checks the protected-paths probe once per second
        // while the request screen is shown. As soon as macOS toggles the
        // permission on, we animate to the success state.
        poller = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            guard phase == .request else { return }
            let granted = FullDiskAccessManager.shared.hasFullDiskAccess
            if granted {
                withAnimation(AppAnimation.sectionTransition) {
                    phase = .granted
                }
            }
        }
    }

    private func stopPolling() {
        poller?.invalidate()
        poller = nil
    }

    private func finish() {
        stopPolling()
        withAnimation(.easeInOut(duration: 0.35)) {
            isComplete = true
        }
    }
}
