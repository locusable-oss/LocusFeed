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
        .defaultSize(width: 880, height: 560)
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
            }
        }

        Settings {
            Form {
                Text("LocusFeed — unread-first RSS for macOS 15+")
                    .font(.body)
                Text("Mark-all-read and unread machine arrive in later work items.")
                    .foregroundStyle(.secondary)
            }
            .padding()
            .frame(width: 360, height: 120)
        }
    }
}
