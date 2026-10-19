import SwiftUI
import AppKit

struct ContentView: View {
    @EnvironmentObject private var store: ScanStore

    var body: some View {
        ZStack {
            AppBackground()

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
        }
        .frame(minWidth: 1000, minHeight: 680)
        .preferredColorScheme(.dark)
        .onAppear {
            let arguments = ProcessInfo.processInfo.arguments
            if let index = arguments.firstIndex(of: "--scan-path"), index + 1 < arguments.count {
                store.startScanForTesting(path: arguments[index + 1])
            } else if arguments.contains("--autoscan"), store.phase == .idle {
                store.scanFullDisk()
            }
        }
    }
}

// MARK: - Welcome

private struct WelcomeView: View {
    @EnvironmentObject private var store: ScanStore
    @State private var scanHover = false
    @State private var showSourceDialog = false

    var body: some View {
        GeometryReader { geo in
            let leftWidth = min(430, geo.size.width * 0.43)
            let heroSide = min(geo.size.height * 0.52, geo.size.width * 0.33)

            ZStack(alignment: .bottom) {
                HStack(alignment: .center, spacing: 24) {
                    leftColumn
                        .frame(width: leftWidth, alignment: .leading)

                    Spacer(minLength: 16)

                    if geo.size.width > 980 {
                        hero(side: heroSide)
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                }
                .padding(.leading, 56)
                .padding(.trailing, 48)
                .padding(.top, 46)
                .padding(.bottom, 118)

                scanButton
                    .padding(.bottom, 36)
            }
        }
    }

    private var leftColumn: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                Image(nsImage: NSApplication.shared.applicationIconImage)
                    .resizable()
                    .interpolation(.high)
                    .frame(width: 28, height: 28)
                Text(verbatim: "DiskScope")
                    .font(.system(size: 15, weight: .semibold))
                    .tracking(0.4)
            }

            Spacer().frame(height: 56)

            VStack(alignment: .leading, spacing: 10) {
                Text("welcome.heroTitle")
                    .font(.system(size: 38, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .fixedSize(horizontal: false, vertical: true)
                Text("welcome.heroSubtitle")
                    .font(.system(size: 13.5))
                    .foregroundStyle(Theme.secondary)
                    .lineSpacing(3)
                    .frame(maxWidth: 380, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer().frame(height: 34)

            VStack(alignment: .leading, spacing: 20) {
                feature(
                    icon: "circle.grid.cross",
                    title: "welcome.feature1.title",
                    message: "welcome.feature1.message"
                )
                feature(
                    icon: "arrow.down.right.and.arrow.up.left",
                    title: "welcome.feature2.title",
                    message: "welcome.feature2.message"
                )
            }

            Spacer().frame(height: 48)

            if !store.hasFullDiskAccess {
                Button {
                    store.openFullDiskAccessSettings()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "lock.shield")
                        Text("welcome.permission.short")
                        Image(systemName: "arrow.up.right")
                            .font(.system(size: 9, weight: .bold))
                    }
                    .font(.system(size: 10.5, weight: .medium))
                    .foregroundStyle(.white.opacity(0.9))
                    .padding(.horizontal, 11)
                    .padding(.vertical, 7)
                    .background(Capsule().fill(Color.orange.opacity(0.18)))
                    .overlay(Capsule().stroke(Color.orange.opacity(0.35), lineWidth: 1))
                }
                .buttonStyle(.plain)
                .padding(.bottom, 12)
            }

            volumeCard

            Spacer(minLength: 0)
        }
    }

    private func feature(icon: String, title: LocalizedStringKey, message: LocalizedStringKey) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 19, weight: .light))
                .foregroundStyle(Color.white.opacity(0.85))
                .frame(width: 28, height: 28)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundStyle(.white)
                Text(message)
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.secondary)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var volumeCard: some View {
        Button {
            showSourceDialog = true
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "internaldrive.fill")
                    .font(.system(size: 24, weight: .light))
                    .foregroundStyle(.white.opacity(0.9))
                    .frame(width: 34)

                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(verbatim: "Macintosh HD")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.white)
                        Spacer(minLength: 8)
                        if let volume = store.volume {
                            Text(Fmt.bytes(volume.totalBytes))
                                .font(.system(size: 10.5))
                                .foregroundStyle(Theme.secondary)
                        }
                    }

                    if let volume = store.volume {
                        GeometryReader { proxy in
                            ZStack(alignment: .leading) {
                                Capsule().fill(Color.white.opacity(0.12))
                                Capsule()
                                    .fill(Color.white.opacity(0.85))
                                    .frame(
                                        width: max(
                                            2,
                                            proxy.size.width * min(
                                                max(Double(volume.usedBytes) / Double(max(volume.totalBytes, 1)), 0),
                                                1
                                            )
                                        )
                                    )
                            }
                        }
                        .frame(height: 4)

                        Text(L10n.format("volume.used", Fmt.bytes(volume.usedBytes)))
                            .font(.system(size: 9.5))
                            .foregroundStyle(Theme.tertiary)
                    }
                }

                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(Theme.tertiary)
            }
            .padding(.horizontal, 13)
            .padding(.vertical, 11)
            .frame(width: 320)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Theme.hairline, lineWidth: 1)
            )
            .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
        .confirmationDialog(
            L10n.t("welcome.sourceTitle"),
            isPresented: $showSourceDialog,
            titleVisibility: .hidden
        ) {
            Button("action.scanDisk") { store.scanFullDisk() }
            Button("action.chooseFolder") { store.chooseFolder() }
            Button("action.cancel", role: .cancel) {}
        }
    }

    private func hero(side: CGFloat) -> some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Theme.accent.opacity(0.28), .clear],
                        center: .center,
                        startRadius: 0,
                        endRadius: side * 0.7
                    )
                )
                .frame(width: side * 1.24, height: side * 1.24)

            Circle()
                .stroke(Color.white.opacity(0.10), lineWidth: 1)
                .frame(width: side * 1.14, height: side * 1.14)
            Circle()
                .stroke(Color.white.opacity(0.07), lineWidth: 1)
                .frame(width: side * 1.38, height: side * 1.38)

            Image(nsImage: NSApplication.shared.applicationIconImage)
                .resizable()
                .interpolation(.high)
                .frame(width: side * 0.74, height: side * 0.74)
                .shadow(color: Color.black.opacity(0.4), radius: 34, y: 18)

            Circle()
                .fill(Color.white.opacity(0.55))
                .frame(width: 5, height: 5)
                .offset(x: side * 0.61, y: -side * 0.42)

            Circle()
                .fill(Color.white.opacity(0.28))
                .frame(width: 7, height: 7)
                .offset(x: -side * 0.66, y: side * 0.28)
        }
        .frame(width: side * 1.48, height: side * 1.48)
    }

    private var scanButton: some View {
        Button {
            store.scanFullDisk()
        } label: {
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.22), lineWidth: 1)
                    .frame(width: 122, height: 122)

                Circle()
                    .fill(Color.white)
                    .frame(width: 92, height: 92)
                    .shadow(color: Theme.accent.opacity(0.65), radius: scanHover ? 26 : 16, y: 6)

                VStack(spacing: 3) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 18, weight: .semibold))
                    Text("action.scan")
                        .font(.system(size: 12, weight: .bold))
                }
                .foregroundStyle(Theme.mid)
            }
            .scaleEffect(scanHover ? 1.04 : 1)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.16)) { scanHover = hovering }
        }
        .help(L10n.t("help.scanDisk"))
    }
}

// MARK: - Scanning

private struct ScanningView: View {
    @EnvironmentObject private var store: ScanStore
    @State private var spin = false

    private var determinate: Bool {
        store.scanIsFullDisk && (store.volume?.usedBytes ?? 0) > 0
    }

    private var fraction: Double {
        guard determinate, let volume = store.volume, volume.usedBytes > 0 else { return 0 }
        return min(max(Double(store.live.bytes) / Double(volume.usedBytes), 0.01), 0.99)
    }

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
                    .frame(width: 220, height: 220)
                Circle()
                    .stroke(Color.white.opacity(0.05), lineWidth: 1)
                    .frame(width: 260, height: 260)
                Image(nsImage: NSApplication.shared.applicationIconImage)
                    .resizable()
                    .interpolation(.high)
                    .frame(width: 132, height: 132)
                    .shadow(color: Color.black.opacity(0.35), radius: 26, y: 12)
            }

            VStack(spacing: 8) {
                Text("scan.building")
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .padding(.top, 26)

                Text(store.lastScanTitle)
                    .font(.system(size: 12.5))
                    .foregroundStyle(Theme.secondary)

                Text(store.live.currentPath)
                    .font(.system(size: 9.5, design: .monospaced))
                    .foregroundStyle(Theme.tertiary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .frame(maxWidth: 540)
                    .padding(.top, 2)
            }

            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.10), lineWidth: 7)
                    .frame(width: 172, height: 172)

                Circle()
                    .trim(from: 0, to: determinate ? fraction : 0.72)
                    .stroke(
                        AngularGradient(
                            colors: [Theme.accent, Color.white, Theme.accent],
                            center: .center
                        ),
                        style: StrokeStyle(lineWidth: 7, lineCap: .round)
                    )
                    .frame(width: 172, height: 172)
                    .rotationEffect(.degrees(determinate ? -90 : (spin ? 270 : -90)))

                Button {
                    store.cancel()
                } label: {
                    VStack(spacing: 2) {
                        Image(systemName: "stop.fill")
                            .font(.system(size: 13))
                        Text("action.stop")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .foregroundStyle(.white)
                    .frame(width: 118, height: 118)
                    .background(Circle().fill(.ultraThinMaterial))
                    .overlay(Circle().stroke(Color.white.opacity(0.16), lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
            .padding(.top, 26)

            VStack(spacing: 6) {
                HStack(spacing: 8) {
                    Text(L10n.files(store.live.files))
                    Text(verbatim: "·")
                    Text(L10n.folders(store.live.dirs))
                    Text(verbatim: "·")
                    Text(Fmt.bytes(store.live.bytes))
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                }
                .font(.system(size: 12))
                .foregroundStyle(Theme.secondary)
                .monospacedDigit()

                if determinate {
                    Text(Fmt.percent(fraction))
                        .font(.system(size: 10))
                        .foregroundStyle(Theme.tertiary)
                        .monospacedDigit()
                } else if let started = store.scanStartedAt {
                    Text(L10n.scanElapsed(Fmt.duration(Date().timeIntervalSince(started))))
                        .font(.system(size: 10))
                        .foregroundStyle(Theme.tertiary)
                        .monospacedDigit()
                }
            }
            .padding(.top, 18)

            Spacer()
        }
        .onAppear {
            withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                spin = true
            }
        }
    }
}

// MARK: - Results

private struct ResultsView: View {
    @EnvironmentObject private var store: ScanStore
    @State private var tab = ProcessInfo.processInfo.arguments.contains("--tab-bigfiles") ? 1 : 0
    @State private var selectedID: String?

    private var entries: [LensEntry] {
        LensEntry.make(from: store.current)
    }

    private var selectedEntry: LensEntry? {
        entries.first { $0.id == selectedID }
    }

    var body: some View {
        VStack(spacing: 0) {
            topBar

            if !store.hasFullDiskAccess {
                permissionStrip
            }

            if tab == 0 {
                LensBrowser(
                    entries: entries,
                    selectedID: $selectedID,
                    onEnter: activate
                )
            } else {
                BigFilesView()
            }

            bottomBar
        }
        .onAppear {
            selectedID = entries.first?.id
        }
        .onChange(of: store.current?.id) { _, _ in
            selectedID = entries.first?.id
        }
    }

    private var topBar: some View {
        VStack(spacing: 0) {
            ZStack {
                HStack {
                    Button {
                        store.go(to: 0)
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 10, weight: .semibold))
                            Text("lens.restart")
                                .font(.system(size: 11.5, weight: .medium))
                        }
                        .foregroundStyle(.white.opacity(0.9))
                        .padding(.horizontal, 11)
                        .padding(.vertical, 6)
                        .background(Capsule().fill(Color.white.opacity(0.07)))
                        .overlay(Capsule().stroke(Theme.hairline, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                    .help(L10n.t("help.restart"))

                    Spacer()

                    Button {
                        store.rescan()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.85))
                            .frame(width: 28, height: 28)
                            .background(Circle().fill(Color.white.opacity(0.07)))
                            .overlay(Circle().stroke(Theme.hairline, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                    .help(L10n.t("help.rescan"))
                }

                Text("lens.title")
                    .font(.system(size: 11.5, weight: .semibold))
                    .foregroundStyle(Theme.secondary)
            }
            .padding(.horizontal, 24)
            .padding(.top, 28)
            .frame(height: 56)

            HStack(spacing: 9) {
                Button {
                    store.goUp()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(store.current?.parent == nil ? Theme.tertiary : .white.opacity(0.8))
                        .frame(width: 22, height: 22)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(store.current?.parent == nil)
                .help(L10n.t("help.back"))

                breadcrumb

                Spacer(minLength: 8)

                ViewSwitcher(selection: $tab)
            }
            .padding(.horizontal, 24)
            .frame(height: 38)
        }
    }

    private var breadcrumb: some View {
        HStack(spacing: 6) {
            Image(systemName: "internaldrive")
                .font(.system(size: 9.5))
                .foregroundStyle(Theme.secondary)

            ForEach(store.breadcrumb.indices, id: \.self) { index in
                if index > 0 {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 7, weight: .bold))
                        .foregroundStyle(Theme.tertiary)
                }

                let node = store.breadcrumb[index]
                Button {
                    store.go(to: index)
                } label: {
                    Text(node.displayName)
                        .font(.system(size: 11, weight: index == store.breadcrumb.count - 1 ? .semibold : .regular))
                        .foregroundStyle(index == store.breadcrumb.count - 1 ? Color.white : Theme.secondary)
                        .lineLimit(1)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 10)
        .frame(height: 26)
        .background(Capsule().fill(Color.white.opacity(0.06)))
        .overlay(Capsule().stroke(Theme.hairline, lineWidth: 1))
    }

    private var permissionStrip: some View {
        HStack(spacing: 8) {
            Image(systemName: "lock.shield")
                .font(.system(size: 11))
                .foregroundStyle(Theme.warm)
            Text("permission.title.denied")
                .font(.system(size: 10.5))
                .foregroundStyle(.white.opacity(0.8))
            Spacer()
            Button {
                store.openFullDiskAccessSettings()
            } label: {
                Text("action.grant")
                    .font(.system(size: 10, weight: .semibold))
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(Color.white.opacity(0.12)))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 24)
        .frame(height: 34)
        .background(Color.orange.opacity(0.10))
    }

    private var bottomBar: some View {
        ZStack {
            HStack(spacing: 8) {
                if let summary = store.summary {
                    HStack(spacing: 6) {
                        Text(L10n.filesFoldersBytes(summary.fileCount, summary.dirCount, Fmt.bytes(summary.totalBytes)))
                            .lineLimit(1)
                        Text(verbatim: "·")
                        Text(L10n.format("status.duration", Fmt.duration(summary.duration)))
                            .lineLimit(1)
                    }
                    .frame(maxWidth: 440, alignment: .leading)

                    Spacer(minLength: 12)

                    if summary.deniedCount > 0 {
                        Label(
                            store.hasFullDiskAccess
                                ? L10n.deniedSystem(summary.deniedCount)
                                : L10n.deniedAccess(summary.deniedCount),
                            systemImage: "lock"
                        )
                        .lineLimit(1)
                        .help(store.hasFullDiskAccess
                              ? L10n.t("status.deniedSystem.help")
                              : L10n.t("status.deniedAccess.help"))
                    }
                }
            }
            .font(.system(size: 10))
            .foregroundStyle(Theme.tertiary)
            .monospacedDigit()
            .padding(.horizontal, 24)

            if tab == 0 {
                actionButton
            }
        }
        .frame(height: 86)
    }

    @ViewBuilder
    private var actionButton: some View {
        if let entry = selectedEntry {
            Button {
                activate(entry)
            } label: {
                VStack(spacing: 4) {
                    Image(systemName: entry.isDirectory ? "folder.fill" : "arrow.up.forward.app")
                        .font(.system(size: 16, weight: .medium))
                    Text(L10n.t(entry.isDirectory ? "lens.open" : "lens.reveal"))
                        .font(.system(size: 10, weight: .semibold))
                }
                .foregroundStyle(.white)
                .frame(width: 68, height: 68)
                .background(Circle().fill(.ultraThinMaterial))
                .overlay(Circle().stroke(Color.white.opacity(0.22), lineWidth: 1))
                .shadow(color: Theme.accent.opacity(0.35), radius: 18, y: 6)
            }
            .buttonStyle(.plain)
        } else {
            VStack(spacing: 3) {
                Image(systemName: "cursorarrow")
                    .font(.system(size: 13))
                Text("lens.select")
                    .font(.system(size: 9))
            }
            .foregroundStyle(Theme.tertiary)
            .frame(width: 68, height: 68)
            .background(Circle().fill(Color.white.opacity(0.05)))
            .overlay(Circle().stroke(Color.white.opacity(0.10), lineWidth: 1))
        }
    }

    private func activate(_ entry: LensEntry) {
        if let node = entry.directory {
            store.enter(node)
        } else if let file = entry.file {
            store.reveal(file.path)
        }
    }
}
