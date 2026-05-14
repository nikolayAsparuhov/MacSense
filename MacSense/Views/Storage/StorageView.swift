import SwiftUI

enum StorageTab: String, CaseIterable, Identifiable {
    case size, type
    var id: String { rawValue }
    var labelKey: LocalizationKey { self == .size ? .storageTabSize : .storageTabType }
    var icon: String { self == .size ? "circle.grid.3x3.fill" : "square.grid.2x2.fill" }
}

struct StorageView: View {
    @EnvironmentObject var appState: AppState
    @ObservedObject private var loc = Localization.shared
    @State private var tab: StorageTab = .size

    /// Show the detail layout only after the user has explicitly clicked
    /// Scan in this session AND results exist. Hero stays put on first
    /// entry — explicit opt-in for an expensive scan. While a scan is
    /// running with prior results in memory, detail still renders so
    /// the user sees the live "Scanning…" pill in the toolbar instead
    /// of being bounced back to the hero.
    private var hasScanned: Bool {
        guard appState.userRequestedStorageScan else { return false }
        return (appState.storageReport?.totalScanned ?? 0) > 0
    }

    var body: some View {
        ZStack {
            if hasScanned {
                detailLayout.transition(.contentLift)
            } else {
                heroLayout.transition(.contentLift)
            }
        }
        .clipped()
        .animation(AppAnimation.sectionTransition, value: hasScanned)
    }

    private var heroLayout: some View {
        HeroLanding(
            title: loc.t(.storageTitle),
            tagline: loc.t(.storageTagline),
            secondaryActionTitle: nil, secondaryAction: nil,
            ctaTitle: loc.t(.commonScan),
            ctaIcon: nil,
            ctaGradient: Theme.sectionGradient(for: .storage),
            ctaGlow: Theme.accent(for: .storage),
            ctaDisabled: false,
            ctaAction: {
                appState.scanStorage()
            },
            isScanning: appState.isScanningStorage,
            scanProgress: nil,
            scanLabel: loc.t(.storageScanningFiles)
        ) {
            Hero3DIcon.forSection(.storage, size: 220)
                .frame(height: 320)
        }
    }

    private var detailLayout: some View {
        VStack(spacing: Theme.sectionSpacing) {
            tabSwitcher
                .padding(.horizontal, 28)
                .padding(.top, 24)

            ZStack {
                if tab == .size {
                    SizeTabView().transition(.contentLift)
                } else {
                    TypeTabView().transition(.contentLift)
                }
            }
            .clipped()
            .animation(AppAnimation.sectionTransition, value: tab)
        }
    }

    private var tabSwitcher: some View {
        HStack(spacing: 8) {
            ForEach(StorageTab.allCases) { t in
                Button {
                    withAnimation(AppAnimation.sectionTransition) { tab = t }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: t.icon)
                            .font(.system(size: 11, weight: .bold))
                        Text(loc.t(t.labelKey))
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .foregroundStyle(tab == t ? Color.white : Color.white.opacity(0.6))
                    .padding(.horizontal, 14).padding(.vertical, 7)
                    .background(
                        Capsule().fill(tab == t
                                       ? AnyShapeStyle(Theme.sectionGradient(for: .storage))
                                       : AnyShapeStyle(Color.white.opacity(0.06)))
                    )
                    .overlay(Capsule().strokeBorder(.white.opacity(tab == t ? 0.0 : 0.15), lineWidth: 1))
                }
                .buttonStyle(.plain)
                .noFocusRing()
            }

            Spacer()

            Text(loc.t(.storageUsedFreeFormat, appState.diskInfo.formattedUsed, appState.diskInfo.formattedFree))
                .font(.system(size: 11, weight: .medium).monospacedDigit())
                .foregroundStyle(.white.opacity(0.55))


            if appState.isScanningStorage {
                HStack(spacing: 6) {
                    ProgressView().controlSize(.small).tint(Theme.accent(for: .storage))
                    Text(loc.t(.storageScanning))
                }
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white.opacity(0.85))
                .padding(.horizontal, 12).padding(.vertical, 6)
                .background(Capsule().fill(Theme.accent(for: .storage).opacity(0.18)))
                .overlay(Capsule().strokeBorder(Theme.accent(for: .storage).opacity(0.45), lineWidth: 1))
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
            } else {
                Button { appState.scanStorage() } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.clockwise")
                        Text(loc.t(.storageReScan))
                    }
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.85))
                    .padding(.horizontal, 12).padding(.vertical, 6)
                    .background(Capsule().fill(.white.opacity(0.06)))
                    .overlay(Capsule().strokeBorder(.white.opacity(0.18), lineWidth: 1))
                }
                .buttonStyle(.plain)
                .noFocusRing()
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.78), value: appState.isScanningStorage)
    }
}
