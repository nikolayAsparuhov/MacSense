import SwiftUI

/// CleanMyMac-style sidebar: grouped sections with subtle uppercase
/// headers, status dot per row, soft sliding pill on selection. Brand
/// header at the top with the cyan-azure logo.
struct Sidebar: View {
    @EnvironmentObject var appState: AppState
    @Namespace private var pillNamespace

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            brandHeader
                .padding(.horizontal, 16)
                .padding(.top, 22)
                .padding(.bottom, 18)

            VStack(spacing: 4) {
                ForEach(AppSection.allCases) { section in
                    sidebarRow(for: section)
                }
            }
            .padding(.horizontal, 10)

            Spacer()
        }
        .frame(maxHeight: .infinity)
        .background(sidebarBackground)
        // Tap on any empty area inside the sidebar (between sections,
        // around the footer, in the brand header gap) closes any open
        // inline modal — matches sidebar-row tap behaviour.
        .contentShape(Rectangle())
        .onTapGesture {
            appState.openedCategory = nil
            appState.selectedApp = nil
        }
    }

    // MARK: - Brand

    private var brandHeader: some View {
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Theme.brandGradient)
                Image(systemName: "speedometer")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.white)
            }
            .frame(width: 34, height: 34)
            .shadow(color: Theme.Palette.cyan.opacity(0.45), radius: 8, x: 0, y: 4)

            VStack(alignment: .leading, spacing: 1) {
                Text("MacSense")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                Text("Mac optimizer")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
    }

    // MARK: - Row

    @ViewBuilder
    private func sidebarRow(for section: AppSection) -> some View {
        let isActive = appState.selectedSection == section
        Button {
            withAnimation(AppAnimation.sidebar) {
                appState.selectedSection = section
            }
        } label: {
            HStack(spacing: 12) {
                statusDot(for: section)
                    .frame(width: 6)

                Hero3DIcon.forSection(section, size: 26)
                    .opacity(isActive ? 1.0 : 0.85)

                Text(section.title)
                    .font(.system(size: 14, weight: isActive ? .semibold : .medium))
                    .foregroundStyle(.white.opacity(isActive ? 1.0 : 0.75))

                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 10)
            .padding(.horizontal, 12)
            .background(
                ZStack {
                    if isActive {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Color.white.opacity(0.10))
                            .overlay(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .strokeBorder(Color.white.opacity(0.10), lineWidth: 1)
                            )
                            .matchedGeometryEffect(id: "activePill", in: pillNamespace)
                    }
                }
            )
            // contentShape inside the label so the whole padded
            // rectangle (including the Spacer area) is the hit target.
            // Outside the label it only covers the visible HStack
            // content, leaving Spacer dead.
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .noFocusRing()
    }

    /// Small colored dot indicating the section's status:
    ///   • mint  = healthy / no action needed
    ///   • amber = recommended action available
    ///   • coral = problem detected
    ///   • clear = unknown / not yet scanned
    @ViewBuilder
    private func statusDot(for section: AppSection) -> some View {
        let color = statusColor(for: section)
        Circle()
            .fill(color)
            .frame(width: 7, height: 7)
            .opacity(color == .clear ? 0 : 1)
            .shadow(color: color.opacity(0.6), radius: 4)
    }

    private func statusColor(for section: AppSection) -> Color {
        switch section {
        case .cleanup:
            let total = CleaningCategory.allCases
                .compactMap { appState.categoryResults[$0]?.totalSize }
                .reduce(0, +)
            if total == 0 { return .clear }
            if total > 20_000_000_000 { return Theme.Palette.coral }      // > 20 GB
            if total > 5_000_000_000  { return Theme.Palette.amber }      // 5-20 GB
            return Theme.Palette.mint                                     // < 5 GB
        case .performance:
            guard appState.hasVisitedPerformance else { return .clear }
            switch appState.performanceMonitor.healthStatus {
            case .green:   return Theme.Palette.mint
            case .yellow:  return Theme.Palette.amber
            case .red:     return Theme.Palette.coral
            case .unknown: return .clear
            }
        case .applications:
            return appState.installedApps.isEmpty ? .clear : Theme.Palette.mint
        case .storage:
            // In-progress scan → amber; once report is ready → coral if
            // the volume is ≥ 90% full, otherwise mint.
            if appState.isScanningStorage { return Theme.Palette.amber }
            guard appState.storageReport != nil else { return .clear }
            let total = appState.diskInfo.totalSpace
            let used = appState.diskInfo.usedSpace
            if total > 0 {
                let ratio = Double(used) / Double(total)
                if ratio >= 0.90 { return Theme.Palette.coral }
            }
            return Theme.Palette.mint
        }
    }

    // MARK: - Background

    private var sidebarBackground: some View {
        ZStack {
            Rectangle().fill(.regularMaterial)
            // Faint cyan wash hugging the top so the brand bar feels lit
            // from above — CMM uses a similar trick.
            LinearGradient(
                colors: [Theme.Palette.cyan.opacity(0.08), Color.clear],
                startPoint: .top,
                endPoint: .center
            )
        }
        .ignoresSafeArea()
    }
}
