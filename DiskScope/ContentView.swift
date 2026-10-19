import SwiftUI
import AppKit

struct ContentView: View {
    @EnvironmentObject private var store: ScanStore

    var body: some View {
        VStack(spacing: 0) {
            CapacityBar(volume: store.volume)
            Divider()

            Group {
                switch store.phase {
                case .idle:
                    WelcomeView()
                case .scanning:
                    ScanningView()
                case .done:
                    ResultsView()
                }
            }

            StatusBar(
                summary: store.summary,
                live: store.live,
                isScanning: store.phase == .scanning,
                statusMessage: store.statusMessage,
                hasFullDiskAccess: store.hasFullDiskAccess
            )
        }
        .frame(minWidth: 980, minHeight: 620)
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear {
            let arguments = ProcessInfo.processInfo.arguments
            if let index = arguments.firstIndex(of: "--scan-path"), index + 1 < arguments.count {
                let path = arguments[index + 1]
                store.startScanForTesting(path: path)
            } else if arguments.contains("--autoscan"), store.phase == .idle {
                store.scanFullDisk()
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button {
                    store.rescan()
                } label: {
                    Label("action.rescan", systemImage: "arrow.clockwise")
                }
                .disabled(store.summary == nil)
                .help(L10n.t("help.rescan"))

                Button {
                    store.chooseFolder()
                } label: {
                    Label("action.chooseFolderShort", systemImage: "folder")
                }
                .help(L10n.t("help.chooseFolder"))

                if store.phase == .scanning {
                    Button {
                        store.cancel()
                    } label: {
                        Label("action.stop", systemImage: "stop.circle")
                    }
                    .help(L10n.t("help.stop"))
                }
            }
        }
    }
}

// MARK: - Welcome

private struct WelcomeView: View {
    @EnvironmentObject private var store: ScanStore

    var body: some View {
        VStack(spacing: 22) {
            Spacer()

            Image(nsImage: NSApplication.shared.applicationIconImage)
                .resizable()
                .interpolation(.high)
                .frame(width: 112, height: 112)
                .shadow(color: .black.opacity(0.16), radius: 14, y: 7)

            VStack(spacing: 8) {
                Text(verbatim: "DiskScope")
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                Text("app.tagline")
                    .font(.system(size: 15))
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 12) {
                Button {
                    store.scanFullDisk()
                } label: {
                    Label("action.scanDisk", systemImage: "play.fill")
                        .frame(minWidth: 110)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .keyboardShortcut(.return, modifiers: [])

                Button {
                    store.chooseFolder()
                } label: {
                    Label("action.chooseFolder", systemImage: "folder")
                        .frame(minWidth: 110)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
            }

            if !store.hasFullDiskAccess {
                HStack(spacing: 12) {
                    Image(systemName: "lock.shield")
                        .font(.system(size: 18))
                        .foregroundStyle(.orange)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("welcome.permission.title")
                            .font(.system(size: 12, weight: .semibold))
                        Text("welcome.permission.message")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 8)
                    Button("action.grant") {
                        store.openFullDiskAccessSettings()
                    }
                    .controlSize(.small)
                }
                .padding(12)
                .frame(maxWidth: 520)
                .background(Color.orange.opacity(0.10))
                .clipShape(RoundedRectangle(cornerRadius: 9))
            }

            Text("welcome.privacy")
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(30)
    }
}

// MARK: - Scanning

private struct ScanningView: View {
    @EnvironmentObject private var store: ScanStore

    var body: some View {
        VStack(spacing: 18) {
            Spacer()

            ProgressView()
                .controlSize(.large)

            Text(L10n.scanTitle(store.lastScanTitle))
                .font(.system(size: 18, weight: .semibold))

            VStack(spacing: 5) {
                Text("\(L10n.files(store.live.files)) · \(L10n.folders(store.live.dirs))")
                    .font(.system(size: 13))
                    .monospacedDigit()
                Text(Fmt.bytes(store.live.bytes))
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }

            if !store.live.currentPath.isEmpty {
                Text(store.live.currentPath)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .frame(maxWidth: 520)
            }

            if let started = store.scanStartedAt {
                Text(L10n.scanElapsed(Fmt.duration(Date().timeIntervalSince(started))))
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }

            Button("action.stopScan") {
                store.cancel()
            }
            .controlSize(.regular)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Results

private struct ResultsView: View {
    @EnvironmentObject private var store: ScanStore
    @State private var tab = ProcessInfo.processInfo.arguments.contains("--tab-bigfiles") ? 1 : 0

    var body: some View {
        VStack(spacing: 0) {
            if !store.hasFullDiskAccess {
                PermissionBanner(
                    deniedCount: store.permissionDenied,
                    hasAccess: store.hasFullDiskAccess,
                    onOpenSettings: { store.openFullDiskAccessSettings() }
                )
            }

            HStack {
                Picker("", selection: $tab) {
                    Text("tab.directory").tag(0)
                    Text("tab.bigFiles").tag(1)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(width: 180)

                Spacer()

                if let summary = store.summary {
                    Text(L10n.scanTotal(Fmt.bytes(summary.totalBytes)))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                        .help(L10n.t("help.scanTotal"))
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 9)

            Divider()

            if tab == 0 {
                DirectoryBrowser()
            } else {
                BigFilesView()
            }
        }
    }
}

// MARK: - Directory browser

private enum BrowserEntry: Identifiable {
    case directory(DirNode)
    case file(FileItem)
    case smallFiles(count: Int, bytes: Int64)
    case overflowDirectories(count: Int, bytes: Int64)

    var id: String {
        switch self {
        case .directory(let node):
            return "d-\(ObjectIdentifier(node))"
        case .file(let item):
            return "f-\(item.id.uuidString)"
        case .smallFiles:
            return "small"
        case .overflowDirectories:
            return "overflow"
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
}

struct DirectoryBrowser: View {
    @EnvironmentObject private var store: ScanStore
    @State private var sortKey: SortKey = .size
    @State private var ascending = false

    private var node: DirNode? { store.current }

    var body: some View {
        VStack(spacing: 0) {
            breadcrumb
            columnHeader
            Divider()

            if let node, node.children.isEmpty, node.files.isEmpty, node.smallCount == 0 {
                EmptyHint(
                    icon: node.denied ? "lock" : "tray",
                    title: L10n.t(node.denied ? "dir.denied.title" : "dir.empty.title"),
                    message: L10n.t(node.denied ? "dir.denied.message" : "dir.empty.message")
                )
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(entries) { entry in
                            BrowserRow(
                                entry: entry,
                                total: max(node?.totalBytes ?? 1, 1),
                                onActivate: activate
                            )
                        }
                    }
                    .padding(.bottom, 12)
                }
                .defaultScrollAnchor(.top)
                .id(node?.id)
            }
        }
    }

    private var breadcrumb: some View {
        HStack(spacing: 6) {
            Button {
                store.goUp()
            } label: {
                Image(systemName: "chevron.up")
                    .font(.system(size: 11, weight: .semibold))
            }
            .buttonStyle(.borderless)
            .disabled(node?.parent == nil)
            .help(L10n.t("help.up"))

            ForEach(store.breadcrumb.indices, id: \.self) { index in
                if index > 0 {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 8, weight: .semibold))
                        .foregroundStyle(.tertiary)
                }
                let item = store.breadcrumb[index]
                Button {
                    store.go(to: index)
                } label: {
                    Text(item.displayName)
                        .font(.system(size: 12, weight: index == store.breadcrumb.count - 1 ? .semibold : .regular))
                        .foregroundStyle(index == store.breadcrumb.count - 1 ? .primary : .secondary)
                }
                .buttonStyle(.plain)
            }

            Spacer()

            if let node {
                Text("\(L10n.files(node.fileCount)) · \(Fmt.bytes(node.totalBytes))")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
        }
        .padding(.horizontal, 20)
        .frame(height: 38)
    }

    private var columnHeader: some View {
        HStack(spacing: 12) {
            sortButton(L10n.t("column.name"), key: .name)
                .frame(maxWidth: .infinity, alignment: .leading)

            Spacer(minLength: 0)

            sortButton(L10n.t("column.size"), key: .size)
                .frame(width: 92, alignment: .trailing)

            Text("column.share")
                .frame(width: 150, alignment: .trailing)
        }
        .font(.system(size: 11, weight: .medium))
        .foregroundStyle(.secondary)
        .padding(.horizontal, 20)
        .frame(height: 26)
    }

    private func sortButton(_ title: String, key: SortKey) -> some View {
        Button {
            if sortKey == key {
                ascending.toggle()
            } else {
                sortKey = key
                ascending = key == .name
            }
        } label: {
            HStack(spacing: 3) {
                Text(title)
                if sortKey == key {
                    Image(systemName: ascending ? "chevron.up" : "chevron.down")
                        .font(.system(size: 8, weight: .bold))
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var entries: [BrowserEntry] {
        guard let node else { return [] }

        var directories = node.children
        var files = node.files

        if sortKey == .name {
            directories.sort {
                $0.displayName.localizedStandardCompare($1.displayName) == .orderedAscending
            }
            files.sort {
                $0.name.localizedStandardCompare($1.name) == .orderedAscending
            }
        } else {
            directories.sort { $0.totalBytes > $1.totalBytes }
            files.sort { $0.size > $1.size }
        }

        if ascending {
            directories.reverse()
            files.reverse()
        }

        var result: [BrowserEntry] = []
        let shownDirectories = min(directories.count, 500)
        result.append(contentsOf: directories.prefix(shownDirectories).map { .directory($0) })
        if directories.count > shownDirectories {
            let rest = directories.dropFirst(shownDirectories)
            result.append(.overflowDirectories(
                count: rest.count,
                bytes: rest.reduce(Int64(0)) { $0 + $1.totalBytes }
            ))
        }

        result.append(contentsOf: files.map { .file($0) })
        if node.smallCount > 0 {
            result.append(.smallFiles(count: node.smallCount, bytes: node.smallBytes))
        }
        return result
    }

    private func activate(_ entry: BrowserEntry) {
        switch entry {
        case .directory(let node):
            store.enter(node)
        case .file(let item):
            store.reveal(item.path)
        case .smallFiles, .overflowDirectories:
            break
        }
    }
}

private struct BrowserRow: View {
    let entry: BrowserEntry
    let total: Int64
    let onActivate: (BrowserEntry) -> Void

    @State private var hovering = false

    private var fraction: Double {
        Double(entry.bytes) / Double(max(total, 1))
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: iconName)
                .font(.system(size: 14))
                .foregroundStyle(iconColor)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 12.5, weight: isDirectory ? .medium : .regular))
                    .lineLimit(1)
                    .truncationMode(.middle)
                Text(subtitle)
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Text(Fmt.bytes(entry.bytes))
                .font(.system(size: 12, weight: .medium))
                .monospacedDigit()
                .frame(width: 92, alignment: .trailing)

            HStack(spacing: 8) {
                ShareBar(fraction: fraction)
                    .frame(width: 80)
                Text(Fmt.percent(fraction))
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                    .frame(width: 52, alignment: .trailing)
            }
            .frame(width: 150, alignment: .trailing)
        }
        .padding(.horizontal, 20)
        .frame(height: 46)
        .background(hovering ? Color.primary.opacity(0.045) : Color.clear)
        .overlay(alignment: .bottom) {
            Divider().opacity(0.22)
        }
        .contentShape(Rectangle())
        .onHover { hovering = $0 }
        .onTapGesture { onActivate(entry) }
        .contextMenu {
            switch entry {
            case .directory(let node):
                Button(L10n.t("action.open")) { onActivate(entry) }
                Button(L10n.t("action.reveal")) {
                    NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: node.path)])
                }
            case .file(let item):
                Button(L10n.t("action.reveal")) {
                    NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: item.path)])
                }
            case .smallFiles, .overflowDirectories:
                EmptyView()
            }
        }
        .help(helpText)
    }

    private var isDirectory: Bool {
        if case .directory = entry { return true }
        return false
    }

    private var title: String {
        switch entry {
        case .directory(let node): return node.displayName
        case .file(let item): return item.name
        case .smallFiles(let count, _): return L10n.smallerFiles(count)
        case .overflowDirectories(let count, _): return L10n.remainingFolders(count)
        }
    }

    private var subtitle: String {
        switch entry {
        case .directory(let node):
            return L10n.filesFolders(node.fileCount, node.dirCount)
        case .file(let item):
            return item.fileExtension
        case .smallFiles:
            return L10n.t("dir.belowOneMB")
        case .overflowDirectories:
            return L10n.t("dir.notShown")
        }
    }

    private var iconName: String {
        switch entry {
        case .directory: return "folder.fill"
        case .file: return "doc.fill"
        case .smallFiles: return "doc.on.doc"
        case .overflowDirectories: return "ellipsis.circle"
        }
    }

    private var iconColor: Color {
        switch entry {
        case .directory: return Color(red: 0.29, green: 0.60, blue: 0.98)
        case .file: return .secondary
        case .smallFiles: return Color.secondary.opacity(0.7)
        case .overflowDirectories: return Color.secondary.opacity(0.7)
        }
    }

    private var helpText: String {
        switch entry {
        case .directory(let node): return node.path
        case .file(let item): return item.path
        case .smallFiles, .overflowDirectories: return ""
        }
    }
}
