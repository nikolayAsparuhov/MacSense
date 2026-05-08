import Foundation

/// Drawer state for the Help feature. Lives on `AppState` so any
/// view can flip it open / focus a specific entry without dragging
/// `@Environment` plumbing through the whole tree.
@MainActor
final class HelpController: ObservableObject {
    @Published var isDrawerOpen: Bool = false
    @Published var focusedEntryID: String? = nil
    @Published var searchQuery: String = ""

    /// Open the drawer scrolled to a specific entry. Pass nil to
    /// open with the first entry selected by default.
    func open(at entryID: String?) {
        focusedEntryID = entryID ?? HelpRegistry.entries.first?.id
        searchQuery = ""
        isDrawerOpen = true
    }

    func close() {
        isDrawerOpen = false
    }
}
