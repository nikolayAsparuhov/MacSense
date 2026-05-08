import SwiftUI

/// Full-screen drawer overlay. Two panes: searchable rail on the
/// left, rendered markdown body on the right. Closes on ESC, on
/// backdrop tap, and via the in-header dismiss button.
struct HelpDrawer: View {
    @ObservedObject var controller: HelpController

    private var filteredEntries: [HelpEntry] {
        HelpRegistry.search(controller.searchQuery)
    }

    private var selectedEntry: HelpEntry? {
        guard let id = controller.focusedEntryID else { return filteredEntries.first }
        return HelpRegistry.entry(id: id) ?? filteredEntries.first
    }

    var body: some View {
        ZStack {
            backdrop
            drawerCard
                .frame(maxWidth: 920, maxHeight: 640)
                .padding(.horizontal, 40)
                .padding(.vertical, 40)
        }
        .transition(.opacity.combined(with: .scale(scale: 0.98)))
        .background(
            Button("") { controller.close() }
                .keyboardShortcut(.cancelAction)
                .opacity(0)
                .frame(width: 0, height: 0)
                .accessibilityHidden(true)
        )
    }

    private var backdrop: some View {
        Rectangle()
            .fill(.black.opacity(0.55))
            .ignoresSafeArea()
            .contentShape(Rectangle())
            .onTapGesture { controller.close() }
    }

    private var drawerCard: some View {
        HStack(spacing: 0) {
            rail
                .frame(width: 280)
            Divider().background(Color.white.opacity(0.08))
            detail
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous).fill(.regularMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Color.white.opacity(0.10), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.55), radius: 40, y: 20)
    }

    // MARK: - Rail

    private var rail: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Search help", text: $controller.searchQuery)
                    .textFieldStyle(.plain)
            }
            .padding(.horizontal, 12).padding(.vertical, 10)
            .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color.white.opacity(0.06)))
            .padding(.horizontal, 14)
            .padding(.top, 14)
            .padding(.bottom, 8)

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 2) {
                    ForEach(filteredEntries) { entry in
                        railRow(entry)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.bottom, 12)
            }
        }
    }

    private func railRow(_ entry: HelpEntry) -> some View {
        let isSelected = entry.id == selectedEntry?.id
        return Button {
            controller.focusedEntryID = entry.id
        } label: {
            Text(entry.title)
                .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                .foregroundStyle(isSelected ? .white : .white.opacity(0.75))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 10).padding(.vertical, 7)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(isSelected ? Color.white.opacity(0.10) : Color.clear)
                )
        }
        .buttonStyle(.plain)
        .noFocusRing()
    }

    // MARK: - Detail

    private var detail: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(selectedEntry?.title ?? "Help")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white)
                Spacer()
                Button {
                    controller.close()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.7))
                        .padding(8)
                        .background(Circle().fill(Color.white.opacity(0.08)))
                }
                .buttonStyle(.plain)
                .noFocusRing()
            }
            .padding(.horizontal, 22)
            .padding(.top, 18)
            .padding(.bottom, 12)

            Divider().background(Color.white.opacity(0.08))

            ScrollView {
                if let entry = selectedEntry {
                    Text(renderedBody(for: entry))
                        .font(.system(size: 13))
                        .foregroundStyle(.white.opacity(0.85))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 22)
                        .padding(.vertical, 18)
                        .textSelection(.enabled)
                } else {
                    Text("No entries match your search.")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 22).padding(.top, 18)
                }
            }
        }
    }

    /// Render the markdown body with `AttributedString(markdown:)`.
    /// Inline-only options keep paragraphs separated and let the
    /// `Text` view break lines naturally.
    private func renderedBody(for entry: HelpEntry) -> AttributedString {
        let opts = AttributedString.MarkdownParsingOptions(
            interpretedSyntax: .inlineOnlyPreservingWhitespace
        )
        if let attributed = try? AttributedString(markdown: entry.body, options: opts) {
            return attributed
        }
        return AttributedString(entry.body)
    }
}
