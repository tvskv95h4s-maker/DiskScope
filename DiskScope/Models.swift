import Foundation

// MARK: - Tree model

final class DirNode: Identifiable {
    var id: ObjectIdentifier { ObjectIdentifier(self) }

    let name: String
    let displayName: String
    /// Only set on the scan root: the real filesystem path.
    let fsRoot: String?
    weak var parent: DirNode?

    var children: [DirNode] = []
    var files: [FileItem] = []

    /// Bytes allocated on disk for this subtree (regular files only).
    var totalBytes: Int64 = 0
    var totalLogical: Int64 = 0
    var fileCount: Int = 0
    var dirCount: Int = 0

    /// Direct (non-recursive) values.
    var directBytes: Int64 = 0
    var directLogical: Int64 = 0
    var directCount: Int = 0
    var smallBytes: Int64 = 0
    var smallCount: Int = 0

    var denied = false
    private var cachedPath: String?

    init(name: String, displayName: String? = nil, fsRoot: String? = nil) {
        self.name = name
        self.displayName = displayName ?? name
        self.fsRoot = fsRoot
    }

    var path: String {
        if let cachedPath { return cachedPath }
        let value: String
        if let fsRoot {
            value = fsRoot
        } else if let parent {
            value = parent.path + "/" + name
        } else {
            value = name
        }
        cachedPath = value
        return value
    }

    var subtitle: String {
        if dirCount > 0 {
            return L10n.filesFolders(fileCount, dirCount)
        }
        return L10n.files(fileCount)
    }
}

struct FileItem: Identifiable {
    let id: UUID
    let name: String
    let size: Int64
    let logicalSize: Int64
    weak var directory: DirNode?

    init(name: String, size: Int64, logicalSize: Int64, directory: DirNode?) {
        self.id = UUID()
        self.name = name
        self.size = size
        self.logicalSize = logicalSize
        self.directory = directory
    }

    var path: String {
        guard let directory else { return name }
        return directory.path + "/" + name
    }

    var fileExtension: String {
        let ext = (name as NSString).pathExtension
        return ext.isEmpty ? L10n.t("file.type") : ext.uppercased()
    }
}

// MARK: - Scan results

struct ScanSummary {
    var rootPath: String
    var totalBytes: Int64
    var totalLogical: Int64
    var fileCount: Int
    var dirCount: Int
    var deniedCount: Int
    var skippedMounts: Int
    var duration: TimeInterval
    var cancelled: Bool
    var scannedAt: Date
}

struct ScanResult {
    var root: DirNode
    var topFiles: [FileItem]
    var summary: ScanSummary
}

struct LiveProgress {
    var files: Int = 0
    var dirs: Int = 0
    var bytes: Int64 = 0
    var denied: Int = 0
    var skippedMounts: Int = 0
    var currentPath: String = ""
}

struct VolumeInfo {
    var name: String
    var totalBytes: Int64
    var freeBytes: Int64
    var usedBytes: Int64 { max(0, totalBytes - freeBytes) }
}

enum SortKey: String, CaseIterable {
    case size
    case name
}
