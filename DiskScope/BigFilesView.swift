import SwiftUI

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
        let visible = Array(items.prefix(10_000))
        let totalBytes = visible.reduce(Int64(0)) { $0 + $1.size }

        VStack(spacing: 0) {
            HStack(spacing: 10) {
                TextField("big.search", text: $searchText)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 220)

                Picker("big.minSize", selection: $minimumSize) {
                    Text("≥ 10 MB").tag(Int64(10_000_000))
                    Text("≥ 100 MB").tag(Int64(100_000_000))
                    Text("≥ 500 MB").tag(Int64(500_000_000))
                    Text("≥ 1 GB").tag(Int64(1_000_000_000))
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .frame(width: 120)

                Button {
                    sortDescending.toggle()
                } label: {
                    Label(
                        L10n.t(sortDescending ? "big.sortDesc" : "big.sortAsc"),
                        systemImage: sortDescending ? "arrow.down" : "arrow.up"
                    )
                        .font(.system(size: 11))
                }
                .buttonStyle(.borderless)

                Spacer()

                Text("\(L10n.files(items.count)) · \(Fmt.bytes(totalBytes))")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 9)

            Divider()

            if visible.isEmpty {
                EmptyHint(
                    icon: "doc.text.magnifyingglass",
                    title: L10n.t("big.empty.title"),
                    message: L10n.t("big.empty.message")
                )
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(visible) { item in
                            BigFileRow(item: item, total: max(store.summary?.totalBytes ?? 1, 1))
                        }
                    }
                    .padding(.bottom, 12)
                }
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
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.name)
                    .font(.system(size: 12.5, weight: .medium))
                    .lineLimit(1)
                    .truncationMode(.middle)
                Text(item.path)
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Text(Fmt.percent(Double(item.size) / Double(max(total, 1))))
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
                .monospacedDigit()
                .frame(width: 48, alignment: .trailing)

            Text(Fmt.bytes(item.size))
                .font(.system(size: 12, weight: .semibold))
                .monospacedDigit()
                .frame(width: 92, alignment: .trailing)

            Button {
                NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: item.path)])
            } label: {
                Image(systemName: "folder")
                    .font(.system(size: 12))
            }
            .buttonStyle(.borderless)
            .opacity(hovering ? 1 : 0.35)
            .help(L10n.t("help.reveal"))
        }
        .padding(.horizontal, 20)
        .frame(height: 46)
        .background(hovering ? Color.primary.opacity(0.045) : Color.clear)
        .overlay(alignment: .bottom) {
            Divider().opacity(0.22)
        }
        .contentShape(Rectangle())
        .onHover { hovering = $0 }
        .onTapGesture {
            NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: item.path)])
        }
        .contextMenu {
            Button(L10n.t("action.reveal")) {
                NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: item.path)])
            }
        }
        .help(item.path)
    }
}
