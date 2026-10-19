import SwiftUI

enum Fmt {
    private static let units = ["B", "KB", "MB", "GB", "TB", "PB"]

    static func bytes(_ value: Int64) -> String {
        let clamped = max(0, value)
        var amount = Double(clamped)
        var index = 0
        while amount >= 1000, index < units.count - 1 {
            amount /= 1000
            index += 1
        }
        if index == 0 {
            return "\(Int(amount)) B"
        }
        return String(format: "%.1f %@", amount, units[index])
    }

    static func count(_ value: Int) -> String {
        value.formatted(.number)
    }

    static func percent(_ fraction: Double) -> String {
        guard fraction.isFinite else { return "0%" }
        if fraction <= 0 { return "0%" }
        if fraction < 0.001 { return "<0.1%" }
        return String(format: "%.1f%%", fraction * 100)
    }

    static func duration(_ seconds: TimeInterval) -> String {
        L10n.duration(seconds)
    }
}

// MARK: - Capacity header

struct CapacityBar: View {
    let volume: VolumeInfo?

    private var total: Int64 { max(volume?.totalBytes ?? 0, 1) }
    private var used: Int64 { volume?.usedBytes ?? 0 }
    private var fraction: Double { Double(used) / Double(total) }

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Image(systemName: "internaldrive.fill")
                    .foregroundStyle(.secondary)
                Text(volume?.name ?? "Macintosh HD")
                    .font(.system(size: 13, weight: .semibold))
                Spacer()
                if let volume {
                    Text(L10n.capacity(
                        used: Fmt.bytes(volume.usedBytes),
                        free: Fmt.bytes(volume.freeBytes),
                        total: Fmt.bytes(volume.totalBytes)
                    ))
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
            }

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.primary.opacity(0.09))
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [Color(red: 0.16, green: 0.47, blue: 0.96),
                                         Color(red: 0.36, green: 0.72, blue: 0.98)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: max(4, proxy.size.width * min(max(fraction, 0), 1)))
                }
            }
            .frame(height: 9)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(.regularMaterial)
    }
}

// MARK: - Permission banner

struct PermissionBanner: View {
    let deniedCount: Int
    let hasAccess: Bool
    let onOpenSettings: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "lock.shield")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.orange)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                Text(message)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer(minLength: 12)

            Button("action.openSettings", action: onOpenSettings)
                .controlSize(.small)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .background(Color.orange.opacity(0.10))
        .overlay(alignment: .bottom) {
            Divider().opacity(0.35)
        }
    }

    private var title: String {
        L10n.permissionTitle(granted: hasAccess, denied: deniedCount)
    }

    private var message: String {
        L10n.t("permission.message")
    }
}

// MARK: - Status bar

struct StatusBar: View {
    let summary: ScanSummary?
    let live: LiveProgress
    let isScanning: Bool
    let statusMessage: String?
    let hasFullDiskAccess: Bool

    var body: some View {
        HStack(spacing: 12) {
            if isScanning {
                ProgressView()
                    .controlSize(.small)
                Text(L10n.format("status.scanning", L10n.files(live.files), Fmt.bytes(live.bytes)))
                    .monospacedDigit()
            } else if let summary {
                Text(L10n.filesFoldersBytes(summary.fileCount, summary.dirCount, Fmt.bytes(summary.totalBytes)))
                    .monospacedDigit()
                Text(L10n.format("status.duration", Fmt.duration(summary.duration)))
                    .foregroundStyle(.secondary)
                if summary.skippedMounts > 0 {
                    Text(L10n.mountPoints(summary.skippedMounts))
                        .foregroundStyle(.secondary)
                }
                if summary.deniedCount > 0 {
                    Label(
                        hasFullDiskAccess
                            ? L10n.deniedSystem(summary.deniedCount)
                            : L10n.deniedAccess(summary.deniedCount),
                        systemImage: "lock"
                    )
                    .foregroundStyle(.orange)
                    .help(hasFullDiskAccess
                          ? L10n.t("status.deniedSystem.help")
                          : L10n.t("status.deniedAccess.help"))
                }
                if summary.cancelled {
                    Text("status.cancelled")
                        .foregroundStyle(.orange)
                }
            } else {
                Text("status.ready")
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if let statusMessage {
                Text(statusMessage)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .font(.system(size: 11))
        .padding(.horizontal, 20)
        .frame(height: 30)
        .background(.regularMaterial)
        .overlay(alignment: .top) {
            Divider().opacity(0.35)
        }
    }
}

// MARK: - Small building blocks

struct SizePill: View {
    let bytes: Int64
    var body: some View {
        Text(Fmt.bytes(bytes))
            .font(.system(size: 12, weight: .medium))
            .monospacedDigit()
    }
}

struct ShareBar: View {
    let fraction: Double
    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.primary.opacity(0.07))
                Capsule()
                    .fill(Color.accentColor.opacity(0.55))
                    .frame(width: max(1, proxy.size.width * min(max(fraction, 0), 1)))
            }
        }
        .frame(height: 5)
    }
}

struct EmptyHint: View {
    let icon: String
    let title: String
    let message: String
    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 30, weight: .light))
                .foregroundStyle(.tertiary)
            Text(title)
                .font(.system(size: 14, weight: .semibold))
            Text(message)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(30)
    }
}
