import SwiftUI

/// Tiny `?` chip that surfaces an inline help popover for a given
/// entry id. Drop one next to any non-obvious term in the UI:
///
/// ```swift
/// HelpIcon(entryID: "purgeable-space")
/// ```
struct HelpIcon: View {
    let entryID: String
    var size: CGFloat = 14

    @EnvironmentObject var appState: AppState
    @State private var showingPopover = false

    var body: some View {
        Button {
            showingPopover.toggle()
        } label: {
            Image(systemName: "questionmark.circle.fill")
                .symbolRenderingMode(.hierarchical)
                .font(.system(size: size, weight: .semibold))
                .foregroundStyle(.white.opacity(0.5))
        }
        .buttonStyle(.plain)
        .noFocusRing()
        .help("What's this?")
        .popover(isPresented: $showingPopover, arrowEdge: .top) {
            HelpPopover(entryID: entryID, onReadMore: { id in
                showingPopover = false
                appState.help.open(at: id)
            })
            .frame(width: 320)
            .padding(16)
        }
    }
}
