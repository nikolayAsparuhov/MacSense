import SwiftUI
import AppKit

/// Folder bubble visualization. Translucent stroke-only discs with the
/// real macOS folder icon inside, name + size beneath. Rich hover card
/// surfaces folder type, item count, and modified date on demand.
struct BubbleMapView: View {
    let nodes: [StorageNode]
    var selectedIDs: Set<UUID> = []
    let onTap: (StorageNode) -> Void
    var onToggleSelect: ((StorageNode) -> Void)? = nil

    /// Tracks which bubble's hover card is currently visible. The
    /// matching bubble gets a high zIndex so its tooltip renders on
    /// top of every sibling bubble — without this, neighboring
    /// circles drawn later in the ForEach paint over the card.
    @State private var hoveredID: UUID? = nil

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let layout = BubbleLayout.pack(nodes: nodes, in: size)
            ZStack {
                // Identify rows by `path` rather than `node.id`. The
                // synthetic "Other items" node is rebuilt by the parent
                // every render — its auto-generated UUID changes each
                // time, so an id-based ForEach tears the BubbleView
                // down and back up between frames, dropping its
                // `@State isHovering` and firing onContinuousHover
                // `.ended` → `.active` loops (visible blink). Paths
                // stay constant ("<other>") across renders.
                ForEach(Array(layout.enumerated()), id: \.element.node.path) { _, item in
                    BubbleView(
                        node: item.node,
                        radius: item.radius,
                        canvasSize: size,
                        isSelected: selectedIDs.contains(item.node.id),
                        onHoverChange: { hovering in
                            hoveredID = hovering ? item.node.id : (hoveredID == item.node.id ? nil : hoveredID)
                        },
                        onTap: { onTap(item.node) },
                        onToggleSelect: onToggleSelect.map { cb in { cb(item.node) } }
                    )
                    .position(item.center)
                    .zIndex(hoveredID == item.node.id ? 1000 : 0)
                }
            }
        }
    }
}

// MARK: - Single bubble

private struct BubbleView: View {
    let node: StorageNode
    let radius: CGFloat
    let canvasSize: CGSize
    let isSelected: Bool
    let onHoverChange: (Bool) -> Void
    let onTap: () -> Void
    let onToggleSelect: (() -> Void)?

    /// Select-toggle badge that sits ON the bubble's top edge so it
    /// reads as a notch carved into the rim. Disc is filled with the
    /// page background so the bubble's circular stroke appears to
    /// continue around it on either side. On hover it expands
    /// fluidly from a single point at the very top; on un-hover it
    /// collapses back into the rim. Always shown when the bubble has
    /// a selectable target — even tiny icon-only bubbles get a
    /// proportionally tiny notch (was previously hidden below 34pt
    /// which made small files unselectable).
    @ViewBuilder
    fileprivate var selectBadge: some View {
        if !node.isAggregateOther, onToggleSelect != nil, radius >= 14 {
            let visible = isHovering || isSelected
            // Notch diameter scales with bubble size. Min 14 keeps the
            // smallest icon-only bubbles still clickable; max 36 stops
            // it dominating the rim of huge bubbles.
            let notchDiameter: CGFloat = max(14, min(36, radius * 0.32))
            Button {
                onToggleSelect?()
            } label: {
                ZStack {
                    Circle()
                        .fill(Theme.Palette.surfaceDeep)
                    Circle()
                        .strokeBorder(
                            isSelected
                            ? Theme.Palette.coral.opacity(0.95)
                            : .white.opacity(0.85),
                            lineWidth: 1.5
                        )
                    Image(systemName: isSelected ? "checkmark" : "xmark")
                        .font(.system(size: notchDiameter * 0.42, weight: .bold))
                        .foregroundStyle(
                            isSelected ? Theme.Palette.coral : .white
                        )
                }
                .frame(width: notchDiameter, height: notchDiameter)
            }
            .buttonStyle(.plain)
            .noFocusRing()
            .help(isSelected ? Localization.shared.t(.bubbleMapDeselect) : Localization.shared.t(.bubbleMapSelectDelete))
            // Center sits ON the bubble's top edge so the disc
            // half-overlaps the stroke and reads as a carved notch.
            .position(x: radius, y: 0)
            .scaleEffect(visible ? 1.0 : 0.0, anchor: .top)
            .opacity(visible ? 1.0 : 0.0)
            .animation(.spring(response: 0.32, dampingFraction: 0.72),
                       value: visible)
        }
    }

    @State private var isHovering = false
    @State private var hoverInfo: HoverInfo?
    @State private var mouseLocation: CGPoint = .zero

    private var showsLabels: Bool { radius >= 36 }
    private var showsIcon:   Bool { radius >= 28 }
    private var iconSide:    CGFloat { min(radius * 0.85, 90) }
    private var labelFont:   CGFloat { min(20, max(11, radius * 0.18)) }
    private var sizeFont:    CGFloat { min(15, max(10, radius * 0.14)) }

    var body: some View {
        ZStack {
                // Translucent fill — single lavender tint, slightly
                // brighter on hover so the user sees the active disc.
                Circle()
                    .fill(LinearGradient(
                        colors: [
                            Color.white.opacity(isHovering ? 0.18 : 0.10),
                            Color.white.opacity(isHovering ? 0.06 : 0.02),
                        ],
                        startPoint: .top, endPoint: .bottom
                    ))

                // Glassy rim — two strokes for the inner/outer rim look.
                Circle()
                    .strokeBorder(isSelected
                                  ? Theme.Palette.coral.opacity(0.95)
                                  : .white.opacity(isHovering ? 0.45 : 0.28),
                                  lineWidth: isSelected ? 2.5 : 1.5)
                Circle()
                    .strokeBorder(.white.opacity(0.10), lineWidth: 0.5)
                    .padding(2)

                // Top-light highlight.
                Circle()
                    .fill(RadialGradient(
                        colors: [.white.opacity(0.18), .clear],
                        center: UnitPoint(x: 0.30, y: 0.20),
                        startRadius: 0,
                        endRadius: radius * 0.85
                    ))

            if showsLabels {
                VStack(spacing: max(2, radius * 0.04)) {
                    if showsIcon {
                        FolderIcon(path: node.path, name: node.name)
                            .frame(width: iconSide, height: iconSide)
                    }
                    Text(node.name == "/" ? Localization.shared.t(.bubbleMapMacintoshHD) : node.name)
                        .font(.system(size: labelFont, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .padding(.horizontal, 6)
                    Text(node.formattedSize)
                        .font(.system(size: sizeFont, weight: .medium, design: .rounded).monospacedDigit())
                        .foregroundStyle(.white.opacity(0.85))
                }
                .frame(width: radius * 1.65)
                .shadow(color: .black.opacity(0.55), radius: 2, y: 1)
                .allowsHitTesting(false)
            } else if showsIcon {
                FolderIcon(path: node.path, name: node.name)
                    .frame(width: iconSide, height: iconSide)
                    .shadow(color: .black.opacity(0.4), radius: 2, y: 1)
                    .allowsHitTesting(false)
            }
        }
        .frame(width: radius * 2, height: radius * 2)
        .contentShape(Circle())
        .shadow(color: (isSelected ? Theme.Palette.coral : Theme.Palette.violet)
                    .opacity(isHovering || isSelected ? 0.55 : 0.25),
                radius: isHovering || isSelected ? 18 : 10, y: 4)
        .scaleEffect(isHovering ? 1.04 : 1.0)
        .animation(.spring(response: 0.32, dampingFraction: 0.75), value: isHovering)
        .animation(.easeInOut(duration: 0.15), value: isSelected)
        .overlay(alignment: .topTrailing) { selectBadge }
        // Cmd-click toggles selection (registered with higher priority
        // so the plain click handler doesn't swallow it). Plain click
        // drills into folders; for files (which can't be drilled) the
        // plain click toggles selection instead — hovering an icon-
        // only file circle and clicking it should mark it for delete
        // since there's no other useful interaction.
        .highPriorityGesture(
            TapGesture()
                .modifiers(.command)
                .onEnded { onToggleSelect?() }
        )
        .onTapGesture {
            if !node.isDirectory && onToggleSelect != nil {
                onToggleSelect?()
            } else {
                onTap()
            }
        }
        .onContinuousHover { phase in
            switch phase {
            case .active(let location):
                // `onContinuousHover` fires across the bubble's square
                // bounding box, but the visible shape is a circle. For
                // big bubbles the gap between circle and square corner
                // is large enough that the hover overlay activates
                // well before the cursor touches the disc. Gate by
                // Euclidean distance from the bubble's center so the
                // hover state matches the rendered circle precisely.
                //
                // Hysteresis: a strict `r` check fights the
                // `.scaleEffect(1.04)` applied on hover — the visual
                // grow re-runs hit-testing at the new geometry and
                // can flip the state off on the next continuous-hover
                // event, producing a visible blink (most noticeable
                // on small bubbles where 4% is a meaningful fraction
                // of the rim). Enter on `r`, exit on `r * 1.05` so
                // the scale-induced jitter sits inside the dead band.
                let dx = location.x - radius
                let dy = location.y - radius
                let distSq = dx * dx + dy * dy
                let enterR2 = radius * radius
                let exitR2 = (radius * 1.05) * (radius * 1.05)
                let threshold = isHovering ? exitR2 : enterR2
                if distSq <= threshold {
                    if !isHovering {
                        isHovering = true
                        hoverInfo = HoverInfo.load(for: node)
                        onHoverChange(true)
                    }
                    mouseLocation = location
                } else if isHovering {
                    isHovering = false
                    hoverInfo = nil
                    onHoverChange(false)
                }
            case .ended:
                isHovering = false
                hoverInfo = nil
                onHoverChange(false)
            }
        }
        .overlay(alignment: .topLeading) {
            if isHovering, let info = hoverInfo {
                BubbleHoverCard(info: info)
                    .offset(x: mouseLocation.x + 14, y: mouseLocation.y + 14)
                    .allowsHitTesting(false)
                    .transition(.opacity)
            }
        }
    }
}

// MARK: - Folder icon (NSWorkspace)

private struct FolderIcon: View {
    let path: String
    let name: String

    var body: some View {
        Image(nsImage: Self.icon(for: path))
            .interpolation(.high)
            .resizable()
            .aspectRatio(contentMode: .fit)
    }

    /// macOS folder icons are domain-aware (Applications has the App
    /// Store glyph, Library has the columns, ~/Movies a clapperboard,
    /// etc.) — `NSWorkspace.icon(forFile:)` returns the right one for
    /// each path. Falls back to the generic folder if the path doesn't
    /// resolve.
    private static func icon(for path: String) -> NSImage {
        let ws = NSWorkspace.shared
        if FileManager.default.fileExists(atPath: path) {
            return ws.icon(forFile: path)
        }
        return ws.icon(for: .folder)
    }
}

// MARK: - Hover card

private struct HoverInfo {
    let name: String
    let typeLabel: String
    let typeTint: Color
    let size: String
    let items: Int
    let modified: Date?

    @MainActor
    static func load(for node: StorageNode) -> HoverInfo {
        let (label, tint) = classify(path: node.path)
        let mod = (try? FileManager.default.attributesOfItem(atPath: node.path))?[.modificationDate] as? Date
        return HoverInfo(
            name: node.name == "/" ? Localization.shared.t(.bubbleMapMacintoshHD) : node.name,
            typeLabel: label,
            typeTint: tint,
            size: node.formattedSize,
            items: node.childCount,
            modified: mod
        )
    }

    @MainActor
    private static func classify(path: String) -> (String, Color) {
        let loc = Localization.shared
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        if path == "/" { return (loc.t(.bubbleMapVolume), Theme.Palette.cyan) }
        if path == "/Applications" || path.hasPrefix("/Applications/") { return (loc.t(.bubbleMapApplications), Theme.Palette.cyan) }
        if path == "/Users" || (path.hasPrefix("/Users/") && !path.hasPrefix(home)) { return (loc.t(.bubbleMapUserFolder), Theme.Palette.mint) }
        if path == home || path.hasPrefix(home + "/") { return (loc.t(.bubbleMapYourFolder), Theme.Palette.mint) }
        if path.hasPrefix("/System") || path.hasPrefix("/Library") || path.hasPrefix("/usr") ||
           path.hasPrefix("/private") || path.hasPrefix("/opt") || path.hasPrefix("/bin") ||
           path.hasPrefix("/sbin") || path.hasPrefix("/var") {
            return (loc.t(.bubbleMapSystemFolder), Theme.Palette.amber)
        }
        return (loc.t(.bubbleMapFolder), .white)
    }
}

private struct BubbleHoverCard: View {
    let info: HoverInfo

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(info.name)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(.white)
            Text(info.typeLabel)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(info.typeTint)
            HStack(spacing: 6) {
                Text(Localization.shared.t(.bubbleMapSize)).foregroundStyle(.white.opacity(0.55))
                Text(info.size).foregroundStyle(.white)
                if info.items > 0 {
                    Text("·").foregroundStyle(.white.opacity(0.4))
                    Text(Localization.shared.t(.bubbleMapItemsFormat, formatItems(info.items))).foregroundStyle(.white)
                }
            }
            .font(.system(size: 11, weight: .medium))
            if let mod = info.modified {
                Text(Localization.shared.t(.bubbleMapModifiedFormat, Self.formatter.string(from: mod)))
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.55))
            }
        }
        .padding(.horizontal, 12).padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(.black.opacity(0.78))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(.white.opacity(0.10), lineWidth: 1)
                )
        )
        .frame(width: 240, alignment: .leading)
        .shadow(color: .black.opacity(0.45), radius: 14, y: 6)
    }

    private func formatItems(_ count: Int) -> String {
        if count >= 1_000_000 { return String(format: "%.1fM", Double(count) / 1_000_000) }
        if count >= 1_000 { return String(format: "%.0fK", Double(count) / 1_000) }
        return "\(count)"
    }

    private static let formatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f
    }()
}

// MARK: - Pack layout

enum BubbleLayout {
    struct Placement {
        let node: StorageNode
        let center: CGPoint
        let radius: CGFloat
    }

    static func pack(nodes: [StorageNode], in size: CGSize) -> [Placement] {
        guard !nodes.isEmpty, size.width > 0, size.height > 0 else { return [] }
        let totalSize = nodes.reduce(0) { $0 + Double($1.size) }
        guard totalSize > 0 else { return [] }

        // Initial fill ratio. Shrink iteratively when packing fails so
        // the final layout never overlaps. Cap at min radius so tiny
        // folders don't disappear.
        var fill: Double = 0.62
        for _ in 0..<6 {
            if let result = tryPack(nodes: nodes, in: size, fill: fill) {
                return result
            }
            fill *= 0.82
        }
        // Final attempt: forced even if some nodes get clamped to min
        // radius — better to ship a complete layout than nothing.
        return tryPack(nodes: nodes, in: size, fill: fill, allowFallback: true) ?? []
    }

    /// Single pass at a given fill ratio. Returns nil if any node had to
    /// fall back to an overlapping corner placement (the caller retries
    /// with a smaller fill). When `allowFallback` is true, fallback
    /// placements are allowed in the result.
    private static func tryPack(nodes: [StorageNode], in size: CGSize,
                                fill: Double, allowFallback: Bool = false) -> [Placement]? {
        let totalSize = nodes.reduce(0) { $0 + Double($1.size) }
        let containerArea = Double(size.width * size.height) * fill
        let scale = containerArea / totalSize

        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let maxR = Double(min(size.width, size.height)) * 0.34
        let rawBaseMin: Double = 28
        let rawRadii = nodes.map { node -> Double in
            sqrt((Double(node.size) * scale) / .pi)
        }
        // Area-proportional radii. No artificial ratio cap — when one
        // folder dominates (e.g. Users at 60% of root) it should be
        // visibly bigger, not squashed to 3× its tiny siblings. Small
        // folders stay readable via the `rawBaseMin` floor; the
        // viewport `maxR` ceiling prevents any one bubble from blowing
        // past the canvas. The outer `pack()` retry loop shrinks the
        // global `fill` when nodes can't be placed without overlap, so
        // wide imbalances still settle in 1-2 passes.
        let radiusFor: (Double) -> Double = { raw in
            max(rawBaseMin, min(maxR, raw))
        }

        var placed: [Placement] = []
        for (idx, node) in nodes.enumerated() {
            let radius = radiusFor(rawRadii[idx])
            let r = CGFloat(radius)

            if placed.isEmpty {
                placed.append(.init(node: node, center: center, radius: r))
                continue
            }

            // Proper Archimedean spiral: rho grows linearly with theta
            // so the search ALWAYS escapes the central bubble's orbit
            // within a bounded number of iterations. Previous formula
            // `rho += step / (theta/4)` decayed sub-logarithmically —
            // when one big bubble dominated (e.g. /Library/Developer/
            // CoreSimulator's "Volumes" at 50% of the parent's size),
            // small siblings could never reach a non-overlapping spot
            // and fell back to the corner.
            let rhoStart = Double(r) * 1.4
            let rhoGrowthPerTheta: Double = 0.6
            var theta: Double = 0
            var found = false
            for _ in 0..<10_000 {
                let rho = rhoStart + rhoGrowthPerTheta * theta
                let x = center.x + CGFloat(rho * cos(theta))
                let y = center.y + CGFloat(rho * sin(theta))
                let p = CGPoint(x: x, y: y)

                let pad: CGFloat = 6
                let gap: CGFloat = 14
                let inside = x - r >= pad && y - r >= pad &&
                             x + r <= size.width - pad && y + r <= size.height - pad
                let collides = placed.contains { other in
                    let d = hypot(p.x - other.center.x, p.y - other.center.y)
                    return d < r + other.radius + gap
                }
                if inside && !collides {
                    placed.append(.init(node: node, center: p, radius: r))
                    found = true
                    break
                }
                theta += 0.18
            }
            if !found {
                if !allowFallback { return nil }
                placed.append(.init(node: node,
                                    center: CGPoint(x: r + 4, y: size.height - r - 4),
                                    radius: r))
            }
        }
        return placed
    }
}
