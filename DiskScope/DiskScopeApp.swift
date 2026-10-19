import SwiftUI

@main
struct DiskScopeApp: App {
    @StateObject private var store = ScanStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
        }
        .defaultSize(width: 1180, height: 760)
        .windowStyle(.hiddenTitleBar)
        .commands {
            CommandGroup(after: .newItem) {
                Button("menu.scanDisk") {
                    store.scanFullDisk()
                }
                .keyboardShortcut("r", modifiers: .command)

                Button("menu.chooseFolder") {
                    store.chooseFolder()
                }
                .keyboardShortcut("o", modifiers: .command)
            }
        }
    }
}
