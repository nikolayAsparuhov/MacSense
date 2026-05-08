import SwiftUI

/// Inline popover content. Title + summary paragraph + "Read more →"
/// that defers to the parent to open the full drawer. Falls back to a
/// "missing entry" notice if the bundle parse turned up nothing for
/// this id (so a typo at the call site doesn't render an empty box).
struct HelpPopover: View {
    let entryID: String
    let onReadMore: (String) -> Void

    private var entry: HelpEntry? { HelpRegistry.entry(id: entryID) }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let entry {
                Text(entry.title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.primary)
                Text(entry.summary)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Button {
                    onReadMore(entry.id)
                } label: {
                    HStack(spacing: 4) {
                        Text("Read more")
                        Image(systemName: "arrow.right")
                    }
                    .font(.system(size: 12, weight: .semibold))
                }
                .buttonStyle(.plain)
                .foregroundStyle(Theme.Palette.cyan)
                .noFocusRing()
            } else {
                Text("Help entry missing")
                    .font(.system(size: 13, weight: .semibold))
                Text("`\(entryID)` was not found in the bundle.")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
        }
    }
}
