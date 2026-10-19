import Foundation
import AppKit
import Combine

final class ScanStore: ObservableObject {
    enum Phase {
        case idle
        case scanning
        case done
    }

    @Published var phase: Phase = .idle
    @Published var root: DirNode?
    @Published var current: DirNode?
    @Published var breadcrumb: [DirNode] = []
    @Published var summary: ScanSummary?
    @Published var topFiles: [FileItem] = []
    @Published var live = LiveProgress()
    @Published var volume: VolumeInfo?
    @Published var permissionDenied = 0
    @Published var hasFullDiskAccess = true
    @Published var statusMessage: String?
    @Published var lastScanTitle = ""
    @Published var scanStartedAt: Date?
    @Published var scanIsFullDisk = false

    private var engine: ScanEngine?
    private var progressTimer: DispatchSourceTimer?
    private var generation = 0

    init() {
        refreshVolume()
        hasFullDiskAccess = Self.probeFullDiskAccess()
    }

    deinit {
        progressTimer?.cancel()
        engine?.cancel()
    }

    // MARK: - Scanning

    func scanFullDisk() {
        startScan(path: "/System/Volumes/Data", displayName: "Macintosh HD")
    }

    func chooseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.prompt = L10n.t("action.scan")
        panel.message = L10n.t("panel.message")
        if panel.runModal() == .OK, let url = panel.url {
            startScan(path: url.path, displayName: url.lastPathComponent)
        }
    }

    func startScanForTesting(path: String) {
        guard phase == .idle else { return }
        startScan(path: path, displayName: (path as NSString).lastPathComponent)
    }

    /// "Start over": go back to the scan root, or start a fresh scan when
    /// already there.
    func restart() {
        if breadcrumb.count > 1 {
            go(to: 0)
        } else {
            rescan()
        }
    }

    func rescan() {
        guard let summary else { return }
        startScan(
            path: summary.rootPath,
            displayName: lastScanTitle.isEmpty ? "Macintosh HD" : lastScanTitle
        )
    }

    private func startScan(path: String, displayName: String) {
        engine?.cancel()
        progressTimer?.cancel()
        progressTimer = nil

        generation += 1
        let currentGeneration = generation

        phase = .scanning
        scanStartedAt = Date()
        scanIsFullDisk = (path == "/System/Volumes/Data")
        live = LiveProgress()
        live.currentPath = path
        root = nil
        current = nil
        breadcrumb = []
        summary = nil
        topFiles = []
        statusMessage = nil
        lastScanTitle = displayName

        NSLog("DiskScope: scan started %@", path)
        let configuration = ScanConfiguration(rootPath: path, displayName: displayName)
        let engine = ScanEngine(configuration: configuration)
        self.engine = engine

        let timer = DispatchSource.makeTimerSource(queue: .main)
        timer.schedule(deadline: .now() + .milliseconds(150), repeating: .milliseconds(150))
        timer.setEventHandler { [weak self, weak engine] in
            guard let self, let engine else { return }
            self.live = engine.progress()
        }
        timer.resume()
        progressTimer = timer

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let result = engine.run()
            DispatchQueue.main.async {
                self?.finish(result, generation: currentGeneration)
            }
        }
    }

    func cancel() {
        engine?.cancel()
    }

    private func finish(_ result: ScanResult, generation finishedGeneration: Int) {
        guard finishedGeneration == generation else { return }
        progressTimer?.cancel()
        progressTimer = nil
        engine = nil

        root = result.root
        current = result.root
        breadcrumb = [result.root]
        summary = result.summary
        topFiles = result.topFiles
        permissionDenied = result.summary.deniedCount
        hasFullDiskAccess = Self.probeFullDiskAccess()
        phase = .done

        NSLog("DiskScope: scan finished files=%d dirs=%d bytes=%lld seconds=%.2f denied=%d cancelled=%d",
              result.summary.fileCount, result.summary.dirCount, result.summary.totalBytes,
              result.summary.duration, result.summary.deniedCount, result.summary.cancelled ? 1 : 0)

        if result.summary.cancelled {
            statusMessage = L10n.t("status.cancelled")
        }

        refreshVolume()
    }

    // MARK: - Navigation

    func enter(_ node: DirNode) {
        current = node
        breadcrumb = ancestry(of: node)
    }

    func goUp() {
        guard let parent = current?.parent else { return }
        enter(parent)
    }

    func go(to index: Int) {
        guard breadcrumb.indices.contains(index) else { return }
        current = breadcrumb[index]
        breadcrumb = Array(breadcrumb.prefix(index + 1))
    }

    private func ancestry(of node: DirNode) -> [DirNode] {
        var result: [DirNode] = []
        var cursor: DirNode? = node
        while let item = cursor {
            result.append(item)
            cursor = item.parent
        }
        return result.reversed()
    }

    // MARK: - Actions

    func reveal(_ path: String) {
        let url = URL(fileURLWithPath: path)
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    func openFullDiskAccessSettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles") else {
            return
        }
        NSWorkspace.shared.open(url)
    }

    func quit() {
        NSApp.terminate(nil)
    }

    // MARK: - Volume / permissions

    func refreshVolume() {
        var info = VolumeInfo(name: "Macintosh HD", totalBytes: 0, freeBytes: 0)
        let url = URL(fileURLWithPath: "/System/Volumes/Data")
        if let values = try? url.resourceValues(forKeys: [
            .volumeTotalCapacityKey,
            .volumeAvailableCapacityForImportantUsageKey,
        ]) {
            info.totalBytes = Int64(values.volumeTotalCapacity ?? 0)
            info.freeBytes = values.volumeAvailableCapacityForImportantUsage ?? 0
        }
        if info.totalBytes == 0 {
            var stats = statfs()
            if statfs("/System/Volumes/Data", &stats) == 0 {
                info.totalBytes = Int64(stats.f_blocks) * Int64(stats.f_bsize)
                info.freeBytes = Int64(stats.f_bavail) * Int64(stats.f_bsize)
            }
        }
        volume = info
    }

    private static func probeFullDiskAccess() -> Bool {
        let home = NSHomeDirectory()
        let probes = [
            home + "/Library/Mail",
            home + "/Library/Safari",
            home + "/Library/Application Support/MobileSync",
            home + "/Library/Messages",
        ]
        var foundExistingProbe = false
        for path in probes {
            var isDirectory: ObjCBool = false
            guard FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory),
                  isDirectory.boolValue
            else { continue }
            foundExistingProbe = true
            let fd = open(path, O_RDONLY)
            if fd >= 0 {
                close(fd)
                return true
            }
        }
        return !foundExistingProbe
    }
}
