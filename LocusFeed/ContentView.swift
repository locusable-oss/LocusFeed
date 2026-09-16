import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        NavigationSplitView {
            FeedSidebar()
                .navigationSplitViewColumnWidth(min: 180, ideal: 220, max: 320)
        } detail: {
            FeedDetailView()
        }
        .toolbar {
            ToolbarItemGroup {
                Button {
                    appState.presentAddFeed = true
                } label: {
                    Label("Add Feed", systemImage: "plus")
                }
                Button {
                    appState.refreshAll()
                } label: {
                    if appState.isRefreshing {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Label("Refresh", systemImage: "arrow.clockwise")
                    }
                }
                .disabled(appState.isRefreshing || appState.feeds.isEmpty)
                .help("Fetch and parse all subscribed feeds")
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
        List(selection: Binding(
            get: { appState.selectedFeedID },
            set: { appState.selectFeed(id: $0) }
        )) {
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

private struct FeedDetailView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        if let id = appState.selectedFeedID,
           let feed = appState.feeds.first(where: { $0.id == id }) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .firstTextBaseline) {
                    Text(feed.title.isEmpty ? "Untitled feed" : feed.title)
                        .font(.title2.weight(.semibold))
                    Spacer()
                    if let summary = appState.lastRefreshSummary {
                        Text(summary)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                LabeledContent("Feed URL", value: feed.url)
                if let site = feed.siteURL, !site.isEmpty {
                    LabeledContent("Site", value: site)
                }

                Divider()

                Text("Items")
                    .font(.headline)

                if appState.items.isEmpty {
                    Text("No items yet. Press Refresh to fetch this feed.")
                        .foregroundStyle(.secondary)
                } else {
                    List(appState.items) { item in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(item.title)
                                    .font(.body.weight(item.isRead ? .regular : .semibold))
                                    .lineLimit(2)
                                if !item.isRead {
                                    Text("NEW")
                                        .font(.caption2.weight(.bold))
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Color.accentColor.opacity(0.15))
                                        .clipShape(Capsule())
                                }
                            }
                            if let link = item.link {
                                Text(link)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                            if let published = item.publishedAt {
                                Text(published.formatted(date: .abbreviated, time: .shortened))
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                        .padding(.vertical, 2)
                    }
                    .listStyle(.inset)
                }
                Spacer(minLength: 0)
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
