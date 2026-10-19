import Foundation

/// Small localization facade. Keeping every user-facing format string in one
/// place makes pluralization and locale-specific word order explicit.
enum L10n {
    static func t(_ key: String) -> String {
        NSLocalizedString(key, comment: "")
    }

    static func format(_ key: String, _ arguments: CVarArg...) -> String {
        String(format: t(key), arguments: arguments)
    }

    static func number(_ count: Int) -> String {
        count.formatted(.number)
    }

    private static func counted(_ key: String, _ count: Int) -> String {
        String(format: t(key), number(count))
    }

    static func files(_ count: Int) -> String {
        counted(count == 1 ? "count.file" : "count.files", count)
    }

    static func folders(_ count: Int) -> String {
        counted(count == 1 ? "count.folder" : "count.folders", count)
    }

    static func items(_ count: Int) -> String {
        counted(count == 1 ? "count.item" : "count.items", count)
    }

    static func directories(_ count: Int) -> String {
        counted(count == 1 ? "count.directory" : "count.directories", count)
    }

    static func mountPoints(_ count: Int) -> String {
        counted(count == 1 ? "count.mountPoint" : "count.mountPoints", count)
    }

    static func smallerFiles(_ count: Int) -> String {
        counted(count == 1 ? "dir.smallerFile" : "dir.smallerFiles", count)
    }

    static func remainingFolders(_ count: Int) -> String {
        counted(count == 1 ? "dir.remainingFolder" : "dir.remainingFolders", count)
    }

    static func filesFolders(_ files: Int, _ folders: Int) -> String {
        String(format: t("format.filesFolders"), self.files(files), self.folders(folders))
    }

    static func filesFoldersBytes(_ files: Int, _ folders: Int, _ bytes: String) -> String {
        String(format: t("format.summary"), self.files(files), self.folders(folders), bytes)
    }

    static func capacity(used: String, free: String, total: String) -> String {
        String(format: t("capacity.usage"), used, free, total)
    }

    static func scanTitle(_ name: String) -> String {
        String(format: t("scan.title"), name)
    }

    static func scanElapsed(_ value: String) -> String {
        String(format: t("scan.elapsed"), value)
    }

    static func scanTotal(_ value: String) -> String {
        String(format: t("scan.total"), value)
    }

    static func duration(_ seconds: TimeInterval) -> String {
        if seconds < 60 {
            return String(format: t("duration.seconds"), seconds)
        }
        let minutes = Int(seconds) / 60
        let remainder = Int(seconds) % 60
        return String(format: t("duration.minutes"), minutes, remainder)
    }

    static func deniedSystem(_ count: Int) -> String {
        String(format: t("status.deniedSystem"), number(count))
    }

    static func deniedAccess(_ count: Int) -> String {
        String(format: t("status.deniedAccess"), number(count))
    }

    static func permissionTitle(granted: Bool, denied: Int) -> String {
        granted
            ? String(format: t("permission.title.granted"), number(denied))
            : t("permission.title.denied")
    }
}
