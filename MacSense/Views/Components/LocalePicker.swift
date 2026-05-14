import SwiftUI

/// Sidebar-footer language picker. Shows the current locale's
/// native name, opens a Menu listing every supported `AppLocale`
/// with no flag iconography (flags map to countries, not
/// languages). Picking a language flips `Localization.shared.locale`
/// and the entire UI re-renders live.
struct LocalePicker: View {
    @ObservedObject var localization: Localization

    var body: some View {
        Menu {
            ForEach(AppLocale.allCases) { value in
                Button {
                    localization.locale = value
                } label: {
                    HStack(spacing: 8) {
                        if value == localization.locale {
                            Image(systemName: "checkmark")
                        }
                        Text(value.displayName)
                    }
                }
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "globe")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.7))
                Text(localization.locale.displayName)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.85))
                    .lineLimit(1)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.white.opacity(0.55))
            }
            .padding(.horizontal, 10).padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.white.opacity(0.06))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
            )
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .help(localization.t(.languagePickerTitle))
    }
}
