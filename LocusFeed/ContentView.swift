import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        NavigationSplitView {
            FeedSidebar()
                .navigationSplitViewColumnWidth(min: 160, ideal: 200, max: 280)
        } content: {
            ItemListPane()
                .navigationSplitViewColumnWidth(min: 220, ideal: 300, max: 420)
        } detail: {
            ItemDetailView()
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

                Button {
                    appState.markSelectedFeedAllRead()
                } label: {
                    Label("Mark Feed Read", systemImage: "checkmark.circle")
                }
                .disabled(appState.selectedFeedID == nil || appState.items.allSatisfy(\.isRead))
                .help("Mark all items in the selected feed as read")

                Button {
                    appState.markAllFeedsRead()
                } label: {
                    Label("Mark All Read", systemImage: "checkmark.circle.fill")
                }
                .disabled(appState.feeds.isEmpty)
                .help("Mark every item in every feed as read")
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

// MARK: - Sidebar (feeds)

private struct FeedSidebar: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        List(selection: Binding(
            get: { appState.selectedFeedID },
            set: { appState.selectFeed(id: $0) }
        )) {
            Section {
                ForEach(appState.feeds) { feed in
                    let unread = appState.unreadCount(for: feed.id)
                    let title = feed.title.isEmpty ? feed.url : feed.title
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(title)
                                .font(.body.weight(unread > 0 ? .semibold : .medium))
                                .lineLimit(1)
                            Text(feed.url)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                        Spacer(minLength: 0)
                    }
                    .badge(unread > 0 ? Text("\(unread)") : nil)
                    .accessibilityLabel(unread > 0 ? "\(title), \(unread) unread" : title)
                    .tag(feed.id)
                    .contextMenu {
                        Button("Edit…") { appState.editingFeed = feed }
                        Button("Mark Feed Read") {
                            appState.selectFeed(id: feed.id)
                            appState.markSelectedFeedAllRead()
                        }
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
            } header: {
                HStack {
                    Text("Subscriptions")
                    Spacer(minLength: 8)
                    if appState.totalUnread > 0 {
                        Text("\(appState.totalUnread)")
                            .font(.caption.weight(.semibold))
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                            .accessibilityLabel("\(appState.totalUnread) unread")
                    }
                }
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("LocusFeed")
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

// MARK: - Item list (unread-first)

private struct ItemListPane: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        Group {
            if let feed = appState.selectedFeed {
                List(selection: Binding(
                    get: { appState.selectedItemID },
                    set: { appState.selectItem(id: $0) }
                )) {
                    Section {
                        ForEach(appState.items) { item in
                            ItemRow(item: item)
                                .tag(item.id)
                                .contextMenu {
                                    Button(item.isRead ? "Mark Unread" : "Mark Read") {
                                        appState.toggleItemRead(id: item.id)
                                    }
                                }
                        }
                    } header: {
                        HStack {
                            Text(feed.title.isEmpty ? "Untitled feed" : feed.title)
                            Spacer()
                            let unread = appState.unreadCount(for: feed.id)
                            if unread > 0 {
                                Text("\(unread) unread")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            if let summary = appState.lastRefreshSummary {
                                Text(summary)
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                    }
                }
                .listStyle(.inset)
                .overlay {
                    if appState.items.isEmpty {
                        ContentUnavailableView(
                            "No items yet",
                            systemImage: "tray",
                            description: Text("Press Refresh to fetch this feed.")
                        )
                    }
                }
            } else {
                ContentUnavailableView(
                    "Select a feed",
                    systemImage: "sidebar.left",
                    description: Text("Choose a subscription from the sidebar.")
                )
            }
        }
        .navigationTitle(appState.selectedFeed.map { $0.title.isEmpty ? "Feed" : $0.title } ?? "Items")
    }
}

private struct ItemRow: View {
    let item: FeedItem

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                if !item.isRead {
                    Circle()
                        .fill(Color.accentColor)
                        .frame(width: 7, height: 7)
                }
                Text(item.title)
                    .font(.body.weight(item.isRead ? .regular : .semibold))
                    .foregroundStyle(item.isRead ? .secondary : .primary)
                    .lineLimit(2)
            }
            if let published = item.publishedAt {
                Text(published.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            } else if let link = item.link {
                Text(link)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 2)
    }
}
