import SwiftUI

/// Verdict banner shown above the file list in the expanded app card.
///
/// The scan was always non-destructive; what was missing was a readable
/// summary of it. This is that summary — the level, and one line per thing
/// worth knowing before the delete button is pressed.
struct UninstallSafetyStrip: View {
    let safety: SafetyAssessment

    private var tint: Color {
        switch safety.level {
        case .safe:     return Theme.Palette.mint
        case .review:   return Theme.Palette.amber
        case .highRisk: return Theme.Palette.coral
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: safety.level.systemImage)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(tint)

            VStack(alignment: .leading, spacing: 3) {
                Text(Localization.shared.t(safety.level.titleKey))
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white)
                ForEach(safety.warnings, id: \.self) { warning in
                    Text(warning)
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.65))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(tint.opacity(0.12))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(tint.opacity(0.35), lineWidth: 1)
        )
    }
}

/// Collapsed list of everything the scanner matched and then refused, each
/// with the rule that refused it.
///
/// Without this the refusals were invisible: a file the user expected to see
/// removed simply wasn't in the list, indistinguishable from one the scanner
/// never found.
struct UninstallExcludedList: View {
    let items: [ExcludedItem]
    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) { isExpanded.toggle() }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 9, weight: .bold))
                    Text(Localization.shared.t(.uninstallExcludedSectionFormat, items.count))
                        .font(.system(size: 11, weight: .semibold))
                }
                .foregroundStyle(.white.opacity(0.6))
            }
            .buttonStyle(.plain)
            .noFocusRing()

            if isExpanded {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(items) { item in
                        VStack(alignment: .leading, spacing: 1) {
                            Text(item.url.path)
                                .font(.system(size: 10))
                                .foregroundStyle(.white.opacity(0.55))
                                .lineLimit(1)
                                .truncationMode(.middle)
                            Text(item.rule.localizedLabel)
                                .font(.system(size: 10))
                                .foregroundStyle(.white.opacity(0.35))
                                .lineLimit(1)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(.leading, 15)
            }
        }
    }
}

/// Confirmation step for anything the safety assessment flagged.
struct UninstallConfirmSheet: View {
    let safety: SafetyAssessment
    let fileCount: Int
    let mode: DeletionMode
    let onCancel: () -> Void
    let onConfirm: () -> Void

    /// Says what will actually happen to each group of files. In permanent
    /// mode the admin-owned items still go to the Trash, and the copy has to
    /// say so rather than promise a deletion that won't happen.
    private var bodyLines: [String] {
        switch mode {
        case .trash:
            return [Localization.shared.t(.uninstallConfirmBodyFormat, fileCount)]
        case .permanent:
            let direct = max(fileCount - safety.adminRequiredCount, 0)
            var lines = [Localization.shared.t(.uninstallConfirmBodyPermanentFormat, direct)]
            if safety.adminRequiredCount > 0 {
                lines.append(Localization.shared.t(.uninstallConfirmAdminFallbackFormat,
                                                  safety.adminRequiredCount))
            }
            return lines
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                Image(systemName: safety.level.systemImage)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(safety.level == .highRisk ? Theme.Palette.coral : Theme.Palette.amber)
                Text(Localization.shared.t(.uninstallConfirmTitle))
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 6) {
                ForEach(bodyLines, id: \.self) { line in
                    Text(line)
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(0.8))
                        .fixedSize(horizontal: false, vertical: true)
                }
                ForEach(safety.warnings, id: \.self) { warning in
                    HStack(alignment: .top, spacing: 6) {
                        Text("•").foregroundStyle(.white.opacity(0.5))
                        Text(warning)
                            .font(.system(size: 12))
                            .foregroundStyle(.white.opacity(0.75))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }

            HStack(spacing: 10) {
                Spacer()
                Button(Localization.shared.t(.commonCancel)) { onCancel() }
                    .buttonStyle(.soft)
                Button {
                    onConfirm()
                } label: {
                    Text(Localization.shared.t(mode == .permanent ? .deletionModePermanent : .uninstallConfirmAction))
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14).padding(.vertical, 7)
                        .background(Capsule().fill(Theme.Palette.coral))
                }
                .buttonStyle(.plain)
                .noFocusRing()
            }
        }
        .padding(18)
        .frame(width: 420)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.ultraThinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(.white.opacity(0.12), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.4), radius: 24, x: 0, y: 10)
    }
}
