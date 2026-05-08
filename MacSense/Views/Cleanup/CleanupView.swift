import SwiftUI

/// Two states:
///   - hero: big icon, title, tagline, circular Scan CTA. Shown when no
///     scan results exist yet.
///   - detail: per-category card grid + smart scan summary. Shown after
///     the first scan completes.
///
/// User can return to hero state by clearing results (no UI for that yet —
/// re-scan replaces results, that's the main flow).
struct CleanupView: View {
    @EnvironmentObject var appState: AppState

    /// Show detail when results exist AND no smart scan is currently
    /// running. Re-scanning drops back to the hero loading state — a
    /// scan in flight always shows the loader, never a half-empty grid.
    private var hasScanned: Bool {
        let hasResults = CleaningCategory.allCases.contains(where: { appState.categoryResults[$0] != nil })
        return hasResults && !appState.isSmartScanRunning
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

    // MARK: - Hero (no results yet)

    private var heroLayout: some View {
        HeroLanding(
            title: "Cleanup",
            tagline: "Free up disk space by trimming caches, system junk, trashed files, purgeable bytes, and developer caches.",
            secondaryActionTitle: nil,
            secondaryAction: nil,
            ctaTitle: "Scan",
            ctaIcon: nil,
            ctaGradient: Theme.sectionGradient(for: .cleanup),
            ctaGlow: Theme.accent(for: .cleanup),
            ctaDisabled: false,
            ctaAction: {
                appState.runSmartScan()
            },
            isScanning: appState.isSmartScanRunning,
            scanProgress: appState.smartScanProgress > 0 ? appState.smartScanProgress : nil,
            scanLabel: scanLabel
        ) {
            sparkleHero
        }
        .coachMark(
            id: "smartScan",
            title: "Smart Scan",
            body: "Tap Scan to walk every cleanup category and total recoverable space — read-only, nothing is deleted."
        )
    }

    private var scanLabel: String {
        if appState.isSmartScanRunning {
            let p = Int((appState.smartScanProgress * 100).rounded())
            return "Scanning · \(p)%"
        }
        return "Scanning…"
    }

    private var sparkleHero: some View {
        ZStack {
            Circle()
                .fill(RadialGradient(
                    colors: [Theme.Palette.cyan.opacity(0.45), .clear],
                    center: .center, startRadius: 20, endRadius: 220
                ))
                .frame(width: 380, height: 380)
                .blur(radius: 20)
            Hero3DIcon.forSection(.cleanup, size: 220)
        }
        .frame(height: 320)
    }

    // MARK: - Detail (after scan)

    private var detailLayout: some View {
        let isExpanded = appState.openedCategory != nil
        return ZStack {
            // Grid layer — recedes (blur + dim + tiny scale) when a card opens.
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.sectionSpacing) {
                    heroSummary
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 240), spacing: Theme.sectionSpacing)],
                              spacing: Theme.sectionSpacing) {
                        ForEach(Array(CleaningCategory.allCases.enumerated()), id: \.element) { idx, cat in
                            categoryCard(for: cat)
                                .cascadeAppear(index: idx, base: 0.04, step: 0.045, cap: 0.4)
                        }
                    }
                    ScheduleSection(viewModel: appState.scheduleVM)
                }
                .padding(28)
            }
            .scaleEffect(isExpanded ? 0.96 : 1.0, anchor: .center)
            .blur(radius: isExpanded ? 14 : 0)
            .opacity(isExpanded ? 0.35 : 1.0)
            .allowsHitTesting(!isExpanded)

            // Backdrop — tap-to-dismiss, fades in with the panel.
            if isExpanded {
                Rectangle()
                    .fill(.black.opacity(0.45))
                    .ignoresSafeArea()
                    .contentShape(Rectangle())
                    .onTapGesture { closeExpanded() }
                    .transition(.opacity)
            }

            // Detail panel — slides up from below + scales in.
            if let opened = appState.openedCategory {
                ExpandedCategoryCard(category: opened)
                    .environmentObject(appState)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 28)
                    .shadow(color: Theme.Palette.cyan.opacity(0.35), radius: 30, y: 8)
                    .shadow(color: .black.opacity(0.55), radius: 40, y: 18)
                    .transition(.asymmetric(
                        insertion: .move(edge: .bottom)
                            .combined(with: .opacity)
                            .combined(with: .scale(scale: 0.92, anchor: .bottom)),
                        removal: .move(edge: .bottom)
                            .combined(with: .opacity)
                            .combined(with: .scale(scale: 0.94, anchor: .bottom))
                    ))
                    .zIndex(2)
            }
        }
        .animation(.spring(response: 0.45, dampingFraction: 0.86), value: appState.openedCategory)
        // Hidden ESC handler. `.onExitCommand` requires keyboard
        // focus which the view doesn't have by default; a button
        // bound to `.cancelAction` keyboard shortcut fires on ESC
        // regardless of focus chain.
        .background(
            Button("") {
                if appState.openedCategory != nil { closeExpanded() }
            }
            .keyboardShortcut(.cancelAction)
            .opacity(0)
            .frame(width: 0, height: 0)
            .accessibilityHidden(true)
        )
    }

    private func closeExpanded() {
        withAnimation(.spring(response: 0.45, dampingFraction: 0.86)) {
            appState.openedCategory = nil
        }
    }

    private var heroSummary: some View {
        GlossyCard(accent: Theme.sectionGradient(for: .cleanup), accentColor: Theme.Palette.cyan) {
            HStack(alignment: .center, spacing: 20) {
                Hero3DIcon.forSection(.cleanup, size: 96)
                    .frame(width: 110, height: 110)

                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        Text("Cleanup summary")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(.white)
                        HelpIcon(entryID: "recoverable-space")
                    }

                    if totalRecoverable > 0 {
                        HStack(spacing: 6) {
                            Text("Found")
                                .font(.system(size: 13))
                                .foregroundStyle(.white.opacity(0.7))
                            RollingByteCount(
                                value: Double(totalRecoverable),
                                font: .system(size: 14, weight: .semibold).monospacedDigit(),
                                foreground: AnyShapeStyle(Theme.brandGradient)
                            )
                            .animation(AppAnimation.value, value: totalRecoverable)
                            Text("recoverable across categories.")
                                .font(.system(size: 13))
                                .foregroundStyle(.white.opacity(0.7))
                        }
                    } else if appState.isSmartScanRunning {
                        Text("Scanning every category…")
                            .font(.system(size: 13))
                            .foregroundStyle(.white.opacity(0.7))
                    } else {
                        Text("Nothing recoverable yet — try a full scan.")
                            .font(.system(size: 13))
                            .foregroundStyle(.white.opacity(0.7))
                    }

                }
                .frame(maxWidth: .infinity, alignment: .leading)

                ZStack {
                    if appState.isSmartScanRunning {
                        ScanProgressBar(
                            progress: appState.smartScanProgress > 0 ? appState.smartScanProgress : nil,
                            label: scanLabel,
                            gradient: Theme.brandGradient,
                            glow: Theme.Palette.cyan
                        )
                        .frame(width: 280)
                        .transition(.opacity.combined(with: .scale(scale: 0.95)))
                    } else {
                        Button {
                            appState.runSmartScan()
                        } label: {
                            Text("Re-scan")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(.white)
                                .padding(.vertical, 10)
                                .padding(.horizontal, 20)
                                .background(Capsule().fill(Theme.brandGradient))
                                .overlay(Capsule().strokeBorder(.white.opacity(0.30), lineWidth: 1))
                                .shadow(color: Theme.Palette.cyan.opacity(0.55), radius: 14, x: 0, y: 5)
                                .shadow(color: .black.opacity(0.25), radius: 6, x: 0, y: 2)
                        }
                        .buttonStyle(.plain)
                        .noFocusRing()
                        .transition(.opacity.combined(with: .scale(scale: 0.95)))
                    }
                }
                .animation(.spring(response: 0.35, dampingFraction: 0.78), value: appState.isSmartScanRunning)
            }
        }
    }

    private var totalRecoverable: Int64 {
        CleaningCategory.allCases
            .compactMap { appState.categoryResults[$0]?.totalSize }
            .reduce(0, +)
    }

    @ViewBuilder
    private func categoryCard(for cat: CleaningCategory) -> some View {
        let state = appState.categoryStates[cat] ?? .idle
        let result = appState.categoryResults[cat]
        Button {
            if result != nil {
                withAnimation(.spring(response: 0.45, dampingFraction: 0.86)) {
                    appState.openedCategory = cat
                }
            } else {
                appState.scanCategory(cat)
            }
        } label: {
            GlossyCard(accent: Theme.sectionGradient(for: .cleanup), accentColor: Theme.Palette.cyan) {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Image(systemName: cat.icon)
                            .font(.system(size: 20, weight: .medium))
                            .foregroundStyle(Theme.Palette.cyan)
                        Spacer()
                        statusPill(state: state, result: result)
                    }
                    Text(cat.rawValue)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                    Text(cat.subtitle)
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.6))
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 6)
                    sizeRow(state: state, result: result)
                }
            }
        }
        .buttonStyle(.plain)
        .noFocusRing()
    }

    @ViewBuilder
    private func statusPill(state: CategoryState, result: CategoryResult?) -> some View {
        switch state {
        case .scanning:
            HStack(spacing: 4) {
                ProgressView().controlSize(.mini)
                Text("Scanning")
            }
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(.white.opacity(0.7))
        case .cleaning(let p):
            Text("Cleaning \(Int(p * 100))%")
                .font(.system(size: 10, weight: .semibold))
                .padding(.horizontal, 6).padding(.vertical, 2)
                .background(Capsule().fill(Theme.Palette.amber.opacity(0.2)))
                .foregroundStyle(Theme.Palette.amber)
        case .cleaned(let freed):
            Text("Freed \(ByteCountFormatter.string(fromByteCount: freed, countStyle: .file))")
                .font(.system(size: 10, weight: .semibold))
                .padding(.horizontal, 6).padding(.vertical, 2)
                .background(Capsule().fill(Theme.Palette.mint.opacity(0.2)))
                .foregroundStyle(Theme.Palette.mint)
        case .cleanedWithErrors(let freed, let message):
            VStack(alignment: .leading, spacing: 4) {
                Text("Freed \(ByteCountFormatter.string(fromByteCount: freed, countStyle: .file))")
                    .font(.system(size: 10, weight: .semibold))
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(Capsule().fill(Theme.Palette.amber.opacity(0.2)))
                    .foregroundStyle(Theme.Palette.amber)
                Text(message)
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
        case .scanned:
            if let result, result.itemCount > 0 {
                Text("\(result.itemCount) items")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.7))
            } else {
                Text("Clean").font(.system(size: 10, weight: .semibold)).foregroundStyle(.green)
            }
        case .idle:
            Text("Tap to scan")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.white.opacity(0.6))
        }
    }

    @ViewBuilder
    private func sizeRow(state: CategoryState, result: CategoryResult?) -> some View {
        if let result, result.totalSize > 0 {
            RollingByteCount(
                value: Double(result.totalSize),
                font: .system(size: 24, weight: .bold, design: .rounded),
                foreground: AnyShapeStyle(Theme.sectionGradient(for: .cleanup))
            )
            .animation(AppAnimation.value, value: result.totalSize)
        } else {
            Text("—")
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundStyle(.white.opacity(0.3))
        }
    }
}

