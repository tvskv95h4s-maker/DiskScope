import SwiftUI
import AppKit

// MARK: - Entries shown in the lens

enum LensEntry: Identifiable {
    case directory(DirNode)
    case file(FileItem)
    case smallFiles(count: Int, bytes: Int64)
    case overflowDirectories(count: Int, bytes: Int64)

    var id: String {
        switch self {
        case .directory(let node): return "d-\(ObjectIdentifier(node))"
        case .file(let item): return "f-\(item.id.uuidString)"
        case .smallFiles: return "small"
        case .overflowDirectories: return "overflow"
        }
    }

    var bytes: Int64 {
        switch self {
        case .directory(let node): return node.totalBytes
        case .file(let item): return item.size
        case .smallFiles(_, let bytes): return bytes
        case .overflowDirectories(_, let bytes): return bytes
        }
    }

    var isDirectory: Bool {
        if case .directory = self { return true }
        return false
    }

    var directory: DirNode? {
        if case .directory(let node) = self { return node }
        return nil
    }

    var file: FileItem? {
        if case .file(let item) = self { return item }
        return nil
    }

    var path: String? {
        switch self {
        case .directory(let node): return node.path
        case .file(let item): return item.path
        case .smallFiles, .overflowDirectories: return nil
        }
    }

    var title: String {
        switch self {
        case .directory(let node): return node.displayName
        case .file(let item): return item.name
        case .smallFiles(let count, _): return L10n.smallerFiles(count)
        case .overflowDirectories(let count, _): return L10n.remainingFolders(count)
        }
    }

    var subtitle: String {
        switch self {
        case .directory(let node):
            let direct = node.children.count + node.files.count + (node.smallCount > 0 ? 1 : 0)
            return L10n.items(direct)
        case .file(let item):
            return item.fileExtension
        case .smallFiles:
            return L10n.t("dir.belowOneMB")
        case .overflowDirectories:
            return L10n.t("dir.notShown")
        }
    }

    var fallbackIcon: String? {
        switch self {
        case .directory: return "folder.fill"
        case .file: return "doc.fill"
        case .smallFiles: return "doc.on.doc"
        case .overflowDirectories: return "ellipsis.circle"
        }
    }

    static func make(from node: DirNode?) -> [LensEntry] {
        guard let node else { return [] }
        var result: [LensEntry] = []
        result.append(contentsOf: node.children.prefix(400).map { .directory($0) })
        result.append(contentsOf: node.files.prefix(400).map { .file($0) })
        if node.smallCount > 0 {
            result.append(.smallFiles(count: node.smallCount, bytes: node.smallBytes))
        }
        return result
    }
}

// MARK: - Circle packing

struct PackedCircle: Identifiable {
    let entry: LensEntry
    let center: CGPoint
    let radius: CGFloat

    var id: String { entry.id }
}

enum CirclePacker {
    static func pack(_ entries: [LensEntry], radius: CGFloat) -> [PackedCircle] {
        let sorted = entries.sorted { $0.bytes > $1.bytes }
        let total = Double(sorted.reduce(Int64(0)) { $0 + max($1.bytes, 1) })
        guard total > 0, radius > 60 else { return [] }

        let container = radius - 6
        var pending: [(LensEntry, CGFloat)] = sorted.map { entry in
            let share = Double(max(entry.bytes, 1)) / total
            return (entry, max(22, radius * 0.46 * sqrt(share)))
        }

        var occupied: [(CGPoint, CGFloat)] = []
        var result: [PackedCircle] = []

        // Place the two largest entries side by side. This reads much better
        // than a single centered circle with a ring of satellites.
        if pending.count >= 2 {
            let first = pending[0]
            let second = pending[1]
            let secondShare = Double(max(second.0.bytes, 1)) / total
            let gap = radius * 0.035
            let distance = (first.1 + second.1 + gap) / 2
            let left = CGPoint(x: -distance, y: 0)
            let right = CGPoint(x: distance, y: 0)

            if secondShare > 0.08,
               hypot(left.x, left.y) + first.1 <= container,
               hypot(right.x, right.y) + second.1 <= container {
                occupied = [(left, first.1), (right, second.1)]
                result = [
                    PackedCircle(entry: first.0, center: left, radius: first.1),
                    PackedCircle(entry: second.0, center: right, radius: second.1),
                ]
                pending.removeFirst(2)
            }
        }

        if result.isEmpty, let first = pending.first {
            occupied = [(.zero, first.1)]
            result = [PackedCircle(entry: first.0, center: .zero, radius: first.1)]
            pending.removeFirst()
        }

        for (index, item) in pending.enumerated() {
            let entry = item.0
            var circleRadius = item.1
            var center: CGPoint?
            var attempts = 0
            let startAngle = CGFloat(index) * 2.399963

            while attempts < 4 {
                center = findSpot(
                    radius: circleRadius,
                    occupied: occupied,
                    container: container,
                    startAngle: startAngle
                )
                if center != nil { break }
                circleRadius *= 0.82
                attempts += 1
            }

            guard let point = center, circleRadius >= 14 else { continue }
            occupied.append((point, circleRadius))
            result.append(PackedCircle(entry: entry, center: point, radius: circleRadius))
        }
        return result
    }

    private static func findSpot(
        radius: CGFloat,
        occupied: [(CGPoint, CGFloat)],
        container: CGFloat,
        startAngle: CGFloat = 0
    ) -> CGPoint? {
        guard radius < container else { return nil }
        if occupied.isEmpty { return .zero }

        var angle = startAngle
        var distance: CGFloat = 0
        var step: CGFloat = 1.2
        var iterations = 0

        while distance < container - radius {
            let point = CGPoint(
                x: cos(angle) * distance,
                y: sin(angle) * distance
            )

            if hypot(point.x, point.y) + radius <= container {
                var free = true
                for other in occupied {
                    let gap = hypot(point.x - other.0.x, point.y - other.0.y)
                    if gap < radius + other.1 + 5 {
                        free = false
                        break
                    }
                }
                if free { return point }
            }

            angle += 0.4
            distance += step
            step += 0.015
            iterations += 1
            if iterations > 6000 { break }
        }
        return nil
    }
}

// MARK: - Icons

enum FileIconCache {
    private static let cache = NSCache<NSString, NSImage>()

    static func icon(for path: String?) -> NSImage? {
        guard let path else { return nil }
        if let cached = cache.object(forKey: path as NSString) {
            return cached
        }
        let image = NSWorkspace.shared.icon(forFile: path)
        image.size = NSSize(width: 72, height: 72)
        cache.setObject(image, forKey: path as NSString)
        return image
    }
}

// MARK: - Browser

struct LensBrowser: View {
    let entries: [LensEntry]
    @Binding var selectedID: String?
    var onEnter: (LensEntry) -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            list
                .frame(width: 340)
            canvas
                .aspectRatio(1, contentMode: .fit)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        }
        .padding(.horizontal, 24)
        .padding(.top, 2)
        .padding(.bottom, 4)
    }

    @ViewBuilder
    private var list: some View {
        if entries.isEmpty {
            EmptyHint(
                icon: "tray",
                title: L10n.t("lens.noItems"),
                message: ""
            )
        } else {
            ScrollView(showsIndicators: false) {
                LazyVStack(spacing: 3) {
                    ForEach(Array(entries.prefix(200))) { entry in
                        LensRow(
                            entry: entry,
                            selected: selectedID == entry.id,
                            onSelect: { selectedID = entry.id },
                            onEnter: { onEnter(entry) }
                        )
                    }
                }
                .padding(.vertical, 2)
            }
        }
    }

    @ViewBuilder
    private var canvas: some View {
        if entries.isEmpty {
            EmptyHint(
                icon: "circle.grid.cross",
                title: L10n.t("lens.noItems"),
                message: ""
            )
        } else {
            LensCanvas(
                entries: Array(entries.prefix(18)),
                selectedID: $selectedID,
                onEnter: onEnter,
                hiddenCount: max(0, entries.count - 18)
            )
        }
    }
}

// MARK: - List row

private struct LensRow: View {
    let entry: LensEntry
    let selected: Bool
    let onSelect: () -> Void
    let onEnter: () -> Void

    @State private var hovering = false

    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(selected ? 0.9 : 0.32), lineWidth: 1.2)
                    .frame(width: 14, height: 14)
                if selected {
                    Circle()
                        .fill(Color.white)
                        .frame(width: 8, height: 8)
                }
            }

            icon
                .frame(width: 22, height: 22)

            VStack(alignment: .leading, spacing: 2) {
                Text(entry.title)
                    .font(.system(size: 12.5, weight: .medium))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Text(entry.subtitle)
                    .font(.system(size: 9.5))
                    .foregroundStyle(Theme.tertiary)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            Text(Fmt.bytes(entry.bytes))
                .font(.system(size: 11.5, weight: .semibold))
                .monospacedDigit()
                .foregroundStyle(.white.opacity(0.9))

            if entry.isDirectory {
                Button(action: onEnter) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.white.opacity(hovering ? 0.75 : 0.32))
                        .frame(width: 18, height: 26)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help(L10n.t("lens.open"))
            } else {
                Color.clear.frame(width: 18, height: 26)
            }
        }
        .padding(.horizontal, 11)
        .frame(height: 54)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(selected ? Color.white.opacity(0.13) : (hovering ? Color.white.opacity(0.05) : Color.clear))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(selected ? Color.white.opacity(0.18) : Color.clear, lineWidth: 1)
        )
        .contentShape(Rectangle())
        .onHover { hovering = $0 }
        .onTapGesture(perform: onSelect)
        .onTapGesture(count: 2, perform: onEnter)
        .contextMenu {
            if let path = entry.path {
                Button(L10n.t("action.reveal")) {
                    NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: path)])
                }
            }
        }
        .help(entry.path ?? "")
    }

    @ViewBuilder
    private var icon: some View {
        if let image = FileIconCache.icon(for: entry.path) {
            Image(nsImage: image)
                .resizable()
                .interpolation(.high)
                .aspectRatio(contentMode: .fit)
        } else if let fallback = entry.fallbackIcon {
            Image(systemName: fallback)
                .font(.system(size: 13))
                .foregroundStyle(.white.opacity(0.55))
        }
    }
}

// MARK: - Lens canvas

private struct LensCanvas: View {
    let entries: [LensEntry]
    @Binding var selectedID: String?
    let onEnter: (LensEntry) -> Void
    let hiddenCount: Int

    var body: some View {
        GeometryReader { geo in
            let radius = max(120, min(geo.size.width, geo.size.height) / 2 - 20)
            let packed = CirclePacker.pack(entries, radius: radius)

            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Color.black.opacity(0.24), Color.black.opacity(0.07)],
                            center: .center,
                            startRadius: 0,
                            endRadius: radius
                        )
                    )
                    .frame(width: radius * 2, height: radius * 2)

                Circle()
                    .stroke(Color.white.opacity(0.12), lineWidth: 2)
                    .frame(width: radius * 2, height: radius * 2)

                Circle()
                    .stroke(Color.white.opacity(0.04), lineWidth: 1)
                    .frame(width: radius * 2 + 16, height: radius * 2 + 16)

                ForEach(packed) { item in
                    LensCircle(
                        item: item,
                        selected: selectedID == item.id,
                        onSelect: { selectedID = item.id },
                        onEnter: { onEnter(item.entry) }
                    )
                    .position(
                        x: geo.size.width / 2 + item.center.x,
                        y: geo.size.height / 2 + item.center.y
                    )
                }

                if hiddenCount > 0 {
                    VStack {
                        Spacer()
                        Text(L10n.format("lens.showingTop", L10n.number(18)))
                            .font(.system(size: 9.5))
                            .foregroundStyle(Theme.tertiary)
                            .padding(.bottom, 2)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

// MARK: - Lens circle

private struct LensCircle: View {
    let item: PackedCircle
    let selected: Bool
    let onSelect: () -> Void
    let onEnter: () -> Void

    @State private var hovering = false

    private var radius: CGFloat { item.radius }

    var body: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color.white.opacity(selected ? 0.30 : 0.20),
                            Color.white.opacity(0.055),
                        ],
                        center: .init(x: 0.32, y: 0.28),
                        startRadius: 0,
                        endRadius: radius * 1.5
                    )
                )

            Circle()
                .stroke(
                    selected ? Color.white.opacity(0.95) : Color.white.opacity(0.18),
                    lineWidth: selected ? 2.5 : 1
                )

            content
        }
        .frame(width: radius * 2, height: radius * 2)
        .scaleEffect(hovering ? 1.035 : 1)
        .shadow(
            color: selected ? Theme.accent.opacity(0.55) : Color.black.opacity(0.16),
            radius: selected ? 18 : 9,
            y: 5
        )
        .contentShape(Circle())
        .onHover { hovering = $0 }
        .onTapGesture(perform: onSelect)
        .onTapGesture(count: 2, perform: onEnter)
        .animation(.spring(response: 0.35, dampingFraction: 0.82), value: selected)
        .animation(.easeOut(duration: 0.15), value: hovering)
        .help(item.entry.path ?? item.entry.title)
    }

    @ViewBuilder
    private var content: some View {
        if radius >= 58 {
            VStack(spacing: 2) {
                icon(size: radius * 0.55)
                Text(item.entry.title)
                    .font(.system(size: min(12, max(9, radius * 0.13)), weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Text(Fmt.bytes(item.entry.bytes))
                    .font(.system(size: min(9.5, max(7.5, radius * 0.095))))
                    .foregroundStyle(.white.opacity(0.58))
                    .lineLimit(1)
            }
            .padding(.horizontal, 8)
            .frame(width: radius * 1.8)
        } else if radius >= 34 {
            VStack(spacing: 2) {
                icon(size: radius * 0.56)
                Text(item.entry.title)
                    .font(.system(size: min(10, max(8, radius * 0.15)), weight: .medium))
                    .foregroundStyle(.white.opacity(0.92))
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.8)
            }
            .padding(.horizontal, 5)
            .frame(width: radius * 1.8)
        } else if radius >= 18 {
            icon(size: radius * 0.72)
        } else {
            Circle()
                .fill(Color.white.opacity(0.35))
                .frame(width: max(3, radius * 0.5), height: max(3, radius * 0.5))
        }
    }

    @ViewBuilder
    private func icon(size: CGFloat) -> some View {
        if let image = FileIconCache.icon(for: item.entry.path) {
            Image(nsImage: image)
                .resizable()
                .interpolation(.high)
                .aspectRatio(contentMode: .fit)
                .frame(width: size, height: size)
        } else if let fallback = item.entry.fallbackIcon {
            Image(systemName: fallback)
                .font(.system(size: size * 0.8))
                .foregroundStyle(.white.opacity(0.65))
                .frame(width: size, height: size)
        }
    }
}
