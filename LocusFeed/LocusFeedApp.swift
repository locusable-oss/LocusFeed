import SwiftUI
import AppKit

@main
struct LocusFeedApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup("LocusFeed") {
            ContentView()
                .environmentObject(appState)
        }
        .defaultSize(width: 1100, height: 640)
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button("About LocusFeed") {
                    NSApplication.shared.orderFrontStandardAboutPanel(options: [
                        .applicationName: "LocusFeed",
                    ])
                }
            }
            CommandGroup(after: .newItem) {
                Button("Add Feed…") {
                    appState.presentAddFeed = true
                }
                .keyboardShortcut("n", modifiers: [.command])

                Button("Refresh") {
                    appState.refreshAll()
                }
                .keyboardShortcut("r", modifiers: [.command])

                Divider()

                Button("Mark Feed Read") {
                    appState.markSelectedFeedAllRead()
                }
                .keyboardShortcut("k", modifiers: [.command])

                Button("Mark All Read") {
                    appState.markAllFeedsRead()
                }
                .keyboardShortcut("k", modifiers: [.command, .shift])
            }
        }

        Settings {
            SettingsView()
                .environmentObject(appState)
        }
    }
}

private struct SettingsView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        Form {
            Section("Refresh") {
                Picker("Automatic refresh", selection: Binding(
                    get: { appState.refreshIntervalMinutes },
                    set: { appState.setRefreshIntervalMinutes($0) }
                )) {
                    ForEach(AppSettings.intervalChoices, id: \.minutes) { choice in
                        Text(choice.label).tag(choice.minutes)
                    }
                }
                Text("Manual Refresh is always available from the toolbar (⌘R). Timed refresh reuses the same fetch pipeline.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Section("About") {
                Text("LocusFeed — unread-first RSS for macOS 15+")
                Text("GPL-3.0 — Locusable Studio")
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding()
        .frame(width: 420, height: 220)
    }
}
