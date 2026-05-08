import SwiftUI
import AppKit

/// Schedule subsection rendered inside `CleanupView`'s detail layout.
/// Lets the user opt into a recurring background scan + summary
/// notification at a daily / weekly / monthly cadence over a chosen
/// subset of cleanup categories.
struct ScheduleSection: View {
    @ObservedObject var viewModel: ScheduleViewModel

    var body: some View {
        GlossyCard(accent: Theme.sectionGradient(for: .cleanup), accentColor: Theme.Palette.cyan) {
            VStack(alignment: .leading, spacing: 16) {
                header
                if viewModel.authStatus == .denied {
                    permissionBanner
                }
                if viewModel.isEnabled {
                    Divider().background(Color.white.opacity(0.08))
                    cadencePicker
                    categoryList
                    constraintNote
                    if let last = viewModel.lastRun {
                        lastRunRow(date: last)
                    }
                } else {
                    Text("Off — MacSense will not run scans in the background.")
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(0.55))
                }
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: "calendar.badge.clock")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Theme.Palette.cyan)
                .frame(width: 32, height: 32)
                .background(Circle().fill(Theme.Palette.cyan.opacity(0.12)))

            VStack(alignment: .leading, spacing: 2) {
                Text("Scheduled scan")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                Text(viewModel.isEnabled ? viewModel.summaryLine : "Run a scan automatically and get a summary notification.")
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.6))
            }
            Spacer()
            Toggle("", isOn: Binding(
                get: { viewModel.isEnabled },
                set: { viewModel.setEnabled($0) }
            ))
            .labelsHidden()
            .toggleStyle(.switch)
            .controlSize(.small)
        }
    }

    // MARK: - Permission banner

    private var permissionBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: "bell.slash")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.Palette.amber)
            Text("Notifications are off — turn them on in System Settings to receive scan summaries.")
                .font(.system(size: 12))
                .foregroundStyle(.white.opacity(0.85))
            Spacer()
            Button("Open Settings") {
                NotificationsService.openNotificationSettings()
            }
            .buttonStyle(.plain)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(Theme.Palette.amber)
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 10).fill(Theme.Palette.amber.opacity(0.08)))
        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Theme.Palette.amber.opacity(0.35), lineWidth: 1))
    }

    // MARK: - Cadence

    private var cadencePicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Cadence")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white.opacity(0.7))
            HStack(spacing: 8) {
                ForEach(ScheduleCadence.allCases) { value in
                    let isActive = value == viewModel.cadence
                    Button {
                        viewModel.setCadence(value)
                    } label: {
                        Text(value.label)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(isActive ? .white : .white.opacity(0.7))
                            .padding(.horizontal, 14).padding(.vertical, 6)
                            .background(
                                Capsule().fill(isActive
                                               ? AnyShapeStyle(Theme.sectionGradient(for: .cleanup))
                                               : AnyShapeStyle(Color.white.opacity(0.06)))
                            )
                            .overlay(Capsule().strokeBorder(.white.opacity(isActive ? 0.0 : 0.15), lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Categories

    private var categoryList: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Categories")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white.opacity(0.7))
            VStack(spacing: 6) {
                ForEach(CleaningCategory.allCases) { cat in
                    HStack(spacing: 10) {
                        Toggle("", isOn: Binding(
                            get: { viewModel.categories.contains(cat) },
                            set: { _ in viewModel.toggleCategory(cat) }
                        ))
                        .labelsHidden()
                        .toggleStyle(.checkbox)
                        .controlSize(.small)

                        Image(systemName: cat.icon)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.7))
                            .frame(width: 18)

                        Text(cat.rawValue)
                            .font(.system(size: 13))
                            .foregroundStyle(.white.opacity(0.9))
                        Spacer()
                    }
                    .padding(.vertical, 2)
                }
            }
        }
    }

    // MARK: - Constraint note + last-run row

    private var constraintNote: some View {
        Text("Schedules run while MacSense is open or recently active. macOS may delay background tasks.")
            .font(.system(size: 11))
            .foregroundStyle(.white.opacity(0.45))
            .padding(.top, 2)
    }

    private func lastRunRow(date: Date) -> some View {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        let relative = formatter.localizedString(for: date, relativeTo: Date())
        let bytes = ByteCountFormatter.string(fromByteCount: viewModel.lastTotalRecoverable, countStyle: .file)
        return HStack(spacing: 6) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Theme.Palette.mint)
            Text("Last run \(relative) — \(bytes) recoverable")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.white.opacity(0.7))
            Spacer()
        }
    }
}
