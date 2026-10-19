import SwiftUI
import AppKit

struct BigFilesView: View {
    @EnvironmentObject private var store: ScanStore

    @State private var minimumSize: Int64 = 100_000_000
    @State private var searchText = ""
    @State private var sortDescending = true

    private var items: [FileItem] {
        var result = store.topFiles.filter { $0.size >= minimumSize }
        if !searchText.isEmpty {
            result = result.filter {
                $0.name.localizedCaseInsensitiveContains(searchText)
                    || $0.path.localizedCaseInsensitiveContains(searchText)
            }
        }
        if !sortDescending {
            result.sort { $0.size < $1.size }
        }
        return result
    }

    var body: some View {
        let visible = Array(items.prefix(6_000))
        let totalBytes = visible.reduce(Int64(0)) { $0 + $1.size }

        VStack(spacing: 0) {
            header(count: items.count, bytes: totalBytes)

            Rectangle()
                .fill(Theme.hairline)
                .frame(height: 1)

            if visible.isEmpty {
                EmptyHint(
                    icon: "doc.text.magnifyingglass",
                    title: L10n.t("big.empty.title"),
                    message: L10n.t("big.empty.message")
                )
            } else {
                ScrollView(showsIndicators: false) {
                    LazyVStack(spacing: 0) {
                        ForEach(visible) { item in
                            BigFileRow(
                                item: item,
                                total: max(store.summary?.totalBytes ?? 1, 1)
                            )
                        }
                    }
                    .padding(.bottom, 8)
                }
            }
        }
    }

    private func header(count: Int, bytes: Int64) -> some View {
        HStack(spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 10))
                    .foregroundStyle(Theme.tertiary)

                TextField("big.search", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 11.5))
                    .foregroundStyle(.white)

                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(Theme.tertiary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 10)
            .frame(width: 236, height: 30)
            .background(Capsule().fill(Color.white.opacity(0.07)))
            .overlay(Capsule().stroke(Theme.hairline, lineWidth: 1))

            Menu {
                sizeButton(10_000_000, "≥ 10 MB")
                sizeButton(100_000_000, "≥ 100 MB")
                sizeButton(500_000_000, "≥ 500 MB")
                sizeButton(1_000_000_000, "≥ 1 GB")
            } label: {
                HStack(spacing: 4) {
                    Text(verbatim: sizeLabel)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 7, weight: .bold))
                        .foregroundStyle(Theme.tertiary)
                }
                .font(.system(size: 10.5))
                .foregroundStyle(.white.opacity(0.85))
                .padding(.horizontal, 10)
                .frame(height: 28)
                .background(Capsule().fill(Color.white.opacity(0.07)))
                .overlay(Capsule().stroke(Theme.hairline, lineWidth: 1))
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .buttonStyle(.plain)
            .fixedSize()

            Button {
                sortDescending.toggle()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: sortDescending ? "arrow.down" : "arrow.up")
                        .font(.system(size: 9, weight: .bold))
                    Text(L10n.t(sortDescending ? "big.sortDesc" : "big.sortAsc"))
                        .font(.system(size: 10.5))
                }
                .foregroundStyle(.white.opacity(0.85))
                .padding(.horizontal, 10)
                .frame(height: 28)
                .background(Capsule().fill(Color.white.opacity(0.07)))
                .overlay(Capsule().stroke(Theme.hairline, lineWidth: 1))
            }
            .buttonStyle(.plain)

            Spacer()

            Text("\(L10n.files(count)) · \(Fmt.bytes(bytes))")
                .font(.system(size: 10.5))
                .foregroundStyle(Theme.tertiary)
                .monospacedDigit()
        }
        .padding(.horizontal, 24)
        .frame(height: 50)
    }

    private var sizeLabel: String {
        switch minimumSize {
        case 10_000_000: return "≥ 10 MB"
        case 500_000_000: return "≥ 500 MB"
        case 1_000_000_000: return "≥ 1 GB"
        default: return "≥ 100 MB"
        }
    }

    @ViewBuilder
    private func sizeButton(_ value: Int64, _ title: String) -> some View {
        Button {
            minimumSize = value
        } label: {
            if minimumSize == value {
                Label(title, systemImage: "checkmark")
            } else {
                Text(title)
            }
        }
    }
}

private struct BigFileRow: View {
    let item: FileItem
    let total: Int64

    @State private var hovering = false

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "doc.fill")
                .font(.system(size: 13))
                .foregroundStyle(.white.opacity(0.55))
                .frame(width: 22)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.name)
                    .font(.system(size: 12.5, weight: .medium))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Text(item.path)
                    .font(.system(size: 9.5))
                    .foregroundStyle(Theme.tertiary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer(minLength: 8)

            Text(Fmt.percent(Double(item.size) / Double(max(total, 1))))
                .font(.system(size: 9.5))
                .foregroundStyle(Theme.tertiary)
                .monospacedDigit()
                .frame(width: 44, alignment: .trailing)

            Text(Fmt.bytes(item.size))
                .font(.system(size: 12, weight: .semibold))
                .monospacedDigit()
                .foregroundStyle(.white.opacity(0.92))
                .frame(width: 90, alignment: .trailing)

            Button {
                reveal()
            } label: {
                Image(systemName: "folder")
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(hovering ? 0.8 : 0.25))
                    .frame(width: 22, height: 28)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help(L10n.t("help.reveal"))
        }
        .padding(.horizontal, 24)
        .frame(height: 50)
        .background(hovering ? Color.white.opacity(0.055) : Color.clear)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color.white.opacity(0.055))
                .frame(height: 1)
                .padding(.leading, 58)
        }
        .contentShape(Rectangle())
        .onHover { hovering = $0 }
        .onTapGesture(perform: reveal)
        .contextMenu {
            Button(L10n.t("action.reveal")) { reveal() }
        }
        .help(item.path)
    }

    private func reveal() {
        NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: item.path)])
    }
}
