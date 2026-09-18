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

                Divider()

                Button("Toggle Item Read") {
                    if let id = appState.selectedItemID {
                        appState.toggleItemRead(id: id)
                    }
                }
                .keyboardShortcut("u", modifiers: [.command])
                .disabled(appState.selectedItemID == nil)

                Button("Mark Read and Next") {
                    appState.markReadAndAdvance()
                }
                .keyboardShortcut("j", modifiers: [.command])
                .disabled(appState.selectedFeedID == nil)
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
            Section("Launch") {
                Picker("On launch", selection: Binding(
                    get: { appState.launchBehavior },
                    set: { appState.setLaunchBehavior($0) }
                )) {
                    ForEach(LaunchBehavior.allCases) { behavior in
                        Text(behavior.label).tag(behavior)
                    }
                }
                Text("Saved for the next launch. Refresh on launch uses the same fetch pipeline as the toolbar.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Section("Reading") {
                Picker("Body size", selection: Binding(
                    get: { appState.bodyFontSize },
                    set: { appState.setBodyFontSize($0) }
                )) {
                    ForEach(BodyFontSize.allCases) { size in
                        Text(size.label).tag(size)
                    }
                }
                Text("The quick brown fox reads the feed.")
                    .font(.system(size: appState.bodyFontSize.points))
                    .foregroundStyle(.secondary)
                Picker("List density", selection: Binding(
                    get: { appState.listDensity },
                    set: { appState.setListDensity($0) }
                )) {
                    ForEach(ListDensity.allCases) { density in
                        Text(density.label).tag(density)
                    }
                }
                Toggle("Unread only", isOn: Binding(
                    get: { appState.unreadOnly },
                    set: { appState.setUnreadOnly($0) }
                ))
                Text("Compact hides excerpts. Unread only drops read rows so ⌘J walks the unread stream.")
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
        .frame(width: 460, height: 560)
    }
}
