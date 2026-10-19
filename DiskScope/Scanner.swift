import Foundation
import Darwin

struct ScanConfiguration {
    var rootPath: String
    var displayName: String
    /// Files at least this large are kept individually for the browser.
    var minFileSize: Int64 = 1_000_000
    var maxFilesPerDirectory = 400
    var topFilesLimit = 50_000
    var workerCount: Int = max(2, min(8, ProcessInfo.processInfo.activeProcessorCount - 1))
}

private struct RawFile {
    let name: String
    let alloc: Int64
    let logical: Int64
}

private struct RawDir {
    let path: String
    let name: String
    let directBytes: Int64
    let directLogical: Int64
    let directCount: Int
    let smallBytes: Int64
    let smallCount: Int
    let files: [RawFile]
    let denied: Bool
    let skippedMounts: Int
    let entryErrors: Int
}

/// Parallel directory scanner built on getattrlistbulk(2).
/// Each worker takes one directory off a shared stack, reads it in bulk,
/// and pushes the child directories back. Only aggregate results are kept.
final class ScanEngine: @unchecked Sendable {
    private enum Attr {
        static let name = UInt32(ATTR_CMN_NAME)
        static let devID = UInt32(ATTR_CMN_DEVID)
        static let objType = UInt32(ATTR_CMN_OBJTYPE)
        static let fileID = UInt32(ATTR_CMN_FILEID)
        static let error = UInt32(ATTR_CMN_ERROR)
        static let returned = UInt32(ATTR_CMN_RETURNED_ATTRS)

        static let linkCount = UInt32(ATTR_FILE_LINKCOUNT)
        static let totalSize = UInt32(ATTR_FILE_TOTALSIZE)
        static let allocSize = UInt32(ATTR_FILE_ALLOCSIZE)
    }

    private enum VType {
        static let regular: UInt32 = 1
        static let directory: UInt32 = 2
    }

    private let config: ScanConfiguration
    private let rootDev: dev_t
    private let minFileSize: Int64
    private let bufferSize = 256 * 1024

    private let condition = NSCondition()
    private var queue: [String] = []
    private var results: [RawDir] = []
    private var inFlight = 0
    private var finished = false
    private var cancelled = false

    private var filesCount = 0
    private var dirsCount = 0
    private var bytesCount: Int64 = 0
    private var deniedCount = 0
    private var skippedMountsCount = 0
    private var currentPath = ""
    private var hardlinkInodes = Set<UInt64>()

    init(configuration: ScanConfiguration) {
        self.config = configuration
        self.minFileSize = configuration.minFileSize
        var st = stat()
        if stat(configuration.rootPath, &st) == 0 {
            self.rootDev = st.st_dev
        } else {
            self.rootDev = 0
        }
    }

    // MARK: - Public API

    func run() -> ScanResult {
        let started = Date()
        condition.lock()
        queue.append(config.rootPath)
        condition.unlock()

        DispatchQueue.concurrentPerform(iterations: config.workerCount) { _ in
            self.workerLoop()
        }

        let duration = Date().timeIntervalSince(started)
        let root = buildTree()

        let summary = ScanSummary(
            rootPath: config.rootPath,
            totalBytes: root.totalBytes,
            totalLogical: root.totalLogical,
            fileCount: root.fileCount,
            dirCount: root.dirCount,
            deniedCount: deniedCount,
            skippedMounts: skippedMountsCount,
            duration: duration,
            cancelled: cancelled,
            scannedAt: Date()
        )

        let topFiles = collectTopFiles(root)
        return ScanResult(root: root, topFiles: topFiles, summary: summary)
    }

    func cancel() {
        condition.lock()
        cancelled = true
        finished = true
        queue.removeAll()
        condition.broadcast()
        condition.unlock()
    }

    func progress() -> LiveProgress {
        condition.lock()
        defer { condition.unlock() }
        return LiveProgress(
            files: filesCount,
            dirs: dirsCount,
            bytes: bytesCount,
            denied: deniedCount,
            skippedMounts: skippedMountsCount,
            currentPath: currentPath
        )
    }

    // MARK: - Worker loop

    private func workerLoop() {
        let buffer = UnsafeMutableRawPointer.allocate(byteCount: bufferSize, alignment: 16)
        defer { buffer.deallocate() }
        var attrList = Self.makeAttrList()

        while true {
            condition.lock()
            while queue.isEmpty && !finished {
                condition.wait()
            }
            if finished {
                condition.unlock()
                break
            }
            let path = queue.removeLast()
            inFlight += 1
            currentPath = path
            condition.unlock()

            if isCancelled { break }

            let (raw, children) = scanDirectory(path, buffer: buffer, attrList: &attrList)

            condition.lock()
            inFlight -= 1
            if cancelled {
                condition.unlock()
                break
            }
            results.append(raw)
            queue.append(contentsOf: children)
            filesCount += raw.directCount
            bytesCount += raw.directBytes
            dirsCount += 1
            if raw.denied { deniedCount += 1 }
            skippedMountsCount += raw.skippedMounts
            if queue.isEmpty && inFlight == 0 {
                finished = true
                condition.broadcast()
            }
            condition.unlock()
        }
    }

    private var isCancelled: Bool {
        condition.lock()
        defer { condition.unlock() }
        return cancelled
    }

    private static func makeAttrList() -> attrlist {
        var attrList = attrlist()
        attrList.bitmapcount = UInt16(ATTR_BIT_MAP_COUNT)
        attrList.commonattr = Attr.returned | Attr.name | Attr.devID | Attr.objType | Attr.fileID | Attr.error
        attrList.fileattr = Attr.linkCount | Attr.totalSize | Attr.allocSize
        return attrList
    }

    // MARK: - Directory parsing

    private func scanDirectory(
        _ path: String,
        buffer: UnsafeMutableRawPointer,
        attrList: inout attrlist
    ) -> (RawDir, [String]) {
        let fd = open(path, O_RDONLY | O_DIRECTORY | O_CLOEXEC)
        guard fd >= 0 else {
            return (emptyRaw(path, denied: true), [])
        }
        defer { close(fd) }

        var directBytes: Int64 = 0
        var directLogical: Int64 = 0
        var directCount = 0
        var smallBytes: Int64 = 0
        var smallCount = 0
        var files: [RawFile] = []
        var children: [String] = []
        var denied = false
        var skippedMounts = 0
        var entryErrors = 0

        let prefix = path.hasSuffix("/") ? path : path + "/"
        let base = buffer.assumingMemoryBound(to: UInt8.self)

        while !isCancelled {
            let count = getattrlistbulk(fd, &attrList, buffer, bufferSize, 0)
            if count <= 0 {
                if count < 0 { denied = true }
                break
            }

            var offset = 0
            for _ in 0..<Int(count) {
                guard offset + 24 <= bufferSize else { break }
                let length = u32(base + offset)
                guard length >= 24, offset + Int(length) <= bufferSize else { break }

                let common = u32(base + offset + 4)
                let fileAttrs = u32(base + offset + 16)

                var cursor = offset + 24
                var nameStart = -1
                var nameLength = 0
                if common & Attr.name != 0 {
                    let refOffset = cursor
                    let dataOffset = Int(Int32(bitPattern: u32(base + cursor)))
                    nameLength = Int(u32(base + cursor + 4))
                    cursor += 8
                    nameStart = refOffset + dataOffset
                }

                var device: dev_t = 0
                if common & Attr.devID != 0 {
                    device = Int32(bitPattern: u32(base + cursor))
                    cursor += 4
                }

                var objectType: UInt32 = 0
                if common & Attr.objType != 0 {
                    objectType = u32(base + cursor)
                    cursor += 4
                }

                var fileID: UInt64 = 0
                if common & Attr.fileID != 0 {
                    fileID = u64(base + cursor)
                    cursor += 8
                }

                if common & Attr.error != 0 {
                    entryErrors += 1
                    offset += Int(length)
                    continue
                }

                var linkCount: UInt32 = 0
                var logicalSize: Int64 = 0
                var allocSize: Int64 = 0
                if fileAttrs & Attr.linkCount != 0 {
                    linkCount = u32(base + cursor)
                    cursor += 4
                }
                if fileAttrs & Attr.totalSize != 0 {
                    logicalSize = i64(base + cursor)
                    cursor += 8
                }
                if fileAttrs & Attr.allocSize != 0 {
                    allocSize = i64(base + cursor)
                    cursor += 8
                }

                guard nameLength > 1,
                      nameStart >= 0,
                      nameStart + nameLength <= bufferSize
                else {
                    offset += Int(length)
                    continue
                }

                if objectType == VType.directory {
                    if device != rootDev {
                        skippedMounts += 1
                    } else {
                        let name = decodeName(base: base, start: nameStart, length: nameLength)
                        children.append(prefix + name)
                    }
                } else if objectType == VType.regular {
                    allocSize = max(0, allocSize)
                    if linkCount > 1 {
                        condition.lock()
                        let isNew = hardlinkInodes.insert(fileID).inserted
                        condition.unlock()
                        if !isNew {
                            offset += Int(length)
                            continue
                        }
                    }
                    directCount += 1
                    directBytes += allocSize
                    directLogical += logicalSize

                    if allocSize >= minFileSize {
                        let name = decodeName(base: base, start: nameStart, length: nameLength)
                        files.append(RawFile(name: name, alloc: allocSize, logical: logicalSize))
                    } else {
                        smallBytes += allocSize
                        smallCount += 1
                    }
                }

                offset += Int(length)
            }
        }

        if files.count > config.maxFilesPerDirectory {
            files.sort { $0.alloc > $1.alloc }
            for dropped in files[config.maxFilesPerDirectory...] {
                smallBytes += dropped.alloc
                smallCount += 1
            }
            files.removeSubrange(config.maxFilesPerDirectory...)
        }

        let name = (path as NSString).lastPathComponent
        let raw = RawDir(
            path: path,
            name: name,
            directBytes: directBytes,
            directLogical: directLogical,
            directCount: directCount,
            smallBytes: smallBytes,
            smallCount: smallCount,
            files: files,
            denied: denied,
            skippedMounts: skippedMounts,
            entryErrors: entryErrors
        )
        return (raw, children)
    }

    private func emptyRaw(_ path: String, denied: Bool) -> RawDir {
        RawDir(
            path: path,
            name: (path as NSString).lastPathComponent,
            directBytes: 0,
            directLogical: 0,
            directCount: 0,
            smallBytes: 0,
            smallCount: 0,
            files: [],
            denied: denied,
            skippedMounts: 0,
            entryErrors: 0
        )
    }

    private func decodeName(base: UnsafePointer<UInt8>, start: Int, length: Int) -> String {
        String(decoding: UnsafeRawBufferPointer(start: base + start, count: length - 1), as: UTF8.self)
    }

    // MARK: - Tree building

    private func buildTree() -> DirNode {
        let root = DirNode(
            name: config.displayName,
            displayName: config.displayName,
            fsRoot: config.rootPath
        )

        var nodes: [String: DirNode] = [config.rootPath: root]
        nodes.reserveCapacity(results.count + 1)
        for raw in results where raw.path != config.rootPath {
            nodes[raw.path] = DirNode(name: raw.name)
        }

        for raw in results {
            guard let node = nodes[raw.path] else { continue }
            node.directBytes = raw.directBytes
            node.directLogical = raw.directLogical
            node.directCount = raw.directCount
            node.smallBytes = raw.smallBytes
            node.smallCount = raw.smallCount
            node.denied = raw.denied
            if !raw.files.isEmpty {
                node.files = raw.files.map {
                    FileItem(name: $0.name, size: $0.alloc, logicalSize: $0.logical, directory: node)
                }
            }

            guard raw.path != config.rootPath else { continue }
            let parentPath = (raw.path as NSString).deletingLastPathComponent
            if let parent = nodes[parentPath] {
                parent.children.append(node)
                node.parent = parent
            } else {
                root.children.append(node)
                node.parent = root
            }
        }

        computeTotals(root)
        sortTree(root)
        return root
    }

    @discardableResult
    private func computeTotals(_ node: DirNode) -> (Int64, Int64, Int, Int) {
        var bytes = node.directBytes
        var logical = node.directLogical
        var files = node.directCount
        var dirs = 0
        for child in node.children {
            let r = computeTotals(child)
            bytes += r.0
            logical += r.1
            files += r.2
            dirs += 1 + r.3
        }
        node.totalBytes = bytes
        node.totalLogical = logical
        node.fileCount = files
        node.dirCount = dirs
        return (bytes, logical, files, dirs)
    }

    private func sortTree(_ node: DirNode) {
        node.children.sort { $0.totalBytes > $1.totalBytes }
        node.files.sort { $0.size > $1.size }
        for child in node.children {
            sortTree(child)
        }
    }

    private func collectTopFiles(_ root: DirNode) -> [FileItem] {
        var all: [FileItem] = []
        var stack: [DirNode] = [root]
        while let node = stack.popLast() {
            all.append(contentsOf: node.files)
            stack.append(contentsOf: node.children)
        }
        all.sort { $0.size > $1.size }
        if all.count > config.topFilesLimit {
            all.removeSubrange(config.topFilesLimit...)
        }
        return all
    }

    // MARK: - Raw buffer helpers

    @inline(__always)
    private func u32(_ pointer: UnsafeRawPointer) -> UInt32 {
        pointer.loadUnaligned(as: UInt32.self)
    }

    @inline(__always)
    private func u64(_ pointer: UnsafeRawPointer) -> UInt64 {
        pointer.loadUnaligned(as: UInt64.self)
    }

    @inline(__always)
    private func i64(_ pointer: UnsafeRawPointer) -> Int64 {
        pointer.loadUnaligned(as: Int64.self)
    }
}
