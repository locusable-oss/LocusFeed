import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        NavigationSplitView {
            FeedSidebar()
                .navigationSplitViewColumnWidth(min: 180, ideal: 220, max: 320)
        } detail: {
            FeedDetailPlaceholder()
        }
        .toolbar {
            ToolbarItemGroup {
                Button {
                    appState.presentAddFeed = true
                } label: {
                    Label("Add Feed", systemImage: "plus")
                }
                Button {
                    appState.reload()
                } label: {
                    Label("Reload", systemImage: "arrow.clockwise")
                }
            }
        }
        .sheet(isPresented: $appState.presentAddFeed) {
            FeedEditorSheet(mode: .add)
        }
        .sheet(item: $appState.editingFeed) { feed in
            FeedEditorSheet(mode: .edit(feed))
        }
        .alert("Error", isPresented: Binding(
            get: { appState.errorMessage != nil },
            set: { if !$0 { appState.errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { appState.errorMessage = nil }
        } message: {
            Text(appState.errorMessage ?? "")
        }
    }
}

private struct FeedSidebar: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        List(selection: $appState.selectedFeedID) {
            Section("Subscriptions") {
                ForEach(appState.feeds) { feed in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(feed.title.isEmpty ? feed.url : feed.title)
                            .font(.body.weight(.medium))
                            .lineLimit(1)
                        Text(feed.url)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    .tag(feed.id)
                    .contextMenu {
                        Button("Edit…") { appState.editingFeed = feed }
                        Button("Delete", role: .destructive) {
                            appState.deleteFeed(id: feed.id)
                        }
                    }
                }
                .onDelete { indexSet in
                    for i in indexSet {
                        appState.deleteFeed(id: appState.feeds[i].id)
                    }
                }
            }
        }
        .listStyle(.sidebar)
        .overlay {
            if appState.feeds.isEmpty {
                ContentUnavailableView(
                    "No feeds yet",
                    systemImage: "dot.radiowaves.up.forward",
                    description: Text("Add an RSS or Atom subscription to get started.")
                )
            }
        }
    }
}

private struct FeedDetailPlaceholder: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        if let id = appState.selectedFeedID,
           let feed = appState.feeds.first(where: { $0.id == id }) {
            VStack(alignment: .leading, spacing: 12) {
                Text(feed.title.isEmpty ? "Untitled feed" : feed.title)
                    .font(.title2.weight(.semibold))
                LabeledContent("Feed URL", value: feed.url)
                if let site = feed.siteURL, !site.isEmpty {
                    LabeledContent("Site", value: site)
                }
                Text("Unread-first item list and fetch arrive in later work items. This build covers local feed CRUD + SQLite store.")
                    .foregroundStyle(.secondary)
                    .padding(.top, 8)
                Spacer()
            }
            .padding(24)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        } else {
            ContentUnavailableView(
                "Select a feed",
                systemImage: "sidebar.left",
                description: Text("Choose a subscription or add a new one.")
            )
        }
    }
}
