import SwiftUI

/// Hero header used at the top of every section. Big gradient title block
/// + tagline. Sets the visual tone of the section before the content cards.
struct SectionHero: View {
    let section: AppSection

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Image(systemName: section.iconName)
                    .font(.system(size: 30, weight: .semibold))
                    .gradientText(Theme.sectionGradient(for: section))

                Text(section.title)
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .gradientText(Theme.sectionGradient(for: section))
            }

            Text(section.tagline)
                .font(.system(size: 14, weight: .regular))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
