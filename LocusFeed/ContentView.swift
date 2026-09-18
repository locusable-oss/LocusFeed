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
                .disabled(appState.selectedFeedID == nil || appState.unreadCount(for: appState.selectedFeedID ?? "") == 0)
                .help("Mark all items in the selected feed as read")

                Button {
                    appState.markAllFeedsRead()
                } label: {
                    Label("Mark All Read", systemImage: "checkmark.circle.fill")
                }
                .disabled(appState.feeds.isEmpty || appState.totalUnread == 0)
                .help("Mark every item in every feed as read")

                Divider()

                Button {
                    appState.setUnreadOnly(!appState.unreadOnly)
                } label: {
                    Label("Unread Only", systemImage: appState.unreadOnly ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
                }
                .help(appState.unreadOnly ? "Showing unread items. Click to show read items too." : "Hide read items and keep the unread stream dense")

                Button {
                    appState.cycleDensity()
                } label: {
                    Label(appState.listDensity.label, systemImage: appState.listDensity == .compact ? "list.dash" : "list.bullet")
                }
                .help(appState.listDensity == .compact ? "Switch to comfortable rows" : "Switch to compact rows")

                Button {
                    appState.markReadAndAdvance()
                } label: {
                    Label("Next Unread", systemImage: "arrow.right.circle")
                }
                .disabled(appState.selectedFeedID == nil || appState.unreadCount(for: appState.selectedFeedID ?? "") == 0)
                .help("Mark the selected item read and move to the next unread (⌘J)")
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
                let unreadItems = appState.items.filter { !$0.isRead }
                let readItems = appState.items.filter(\.isRead)
                List(selection: Binding(
                    get: { appState.selectedItemID },
                    set: { appState.selectItem(id: $0) }
                )) {
                    if !unreadItems.isEmpty {
                        Section("Unread") {
                            ForEach(unreadItems) { item in
                                itemRow(item)
                            }
                        }
                    }
                    if !readItems.isEmpty {
                        Section("Read") {
                            ForEach(readItems) { item in
                                itemRow(item)
                            }
                        }
                    }
                }
                .listStyle(.inset)
                .safeAreaInset(edge: .top, spacing: 0) {
                    ItemStreamHeader(feed: feed)
                }
                .overlay {
                    if appState.items.isEmpty {
                        ContentUnavailableView(
                            appState.unreadOnly ? "All caught up" : "No items yet",
                            systemImage: appState.unreadOnly ? "checkmark.circle" : "tray",
                            description: Text(appState.unreadOnly
                                ? "No unread items in this feed."
                                : "Press Refresh to fetch this feed.")
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

    @ViewBuilder
    private func itemRow(_ item: FeedItem) -> some View {
        ItemRow(item: item, density: appState.listDensity) {
            if item.isRead {
                appState.toggleItemRead(id: item.id)
            } else {
                appState.setItemRead(id: item.id, isRead: true)
            }
        }
        .tag(item.id)
        .contextMenu {
            Button(item.isRead ? "Mark Unread" : "Mark Read") {
                appState.toggleItemRead(id: item.id)
            }
            Button("Mark Read and Next") {
                appState.selectedItemID = item.id
                appState.markReadAndAdvance()
            }
        }
    }
}

private struct ItemStreamHeader: View {
    @EnvironmentObject private var appState: AppState
    let feed: Feed

    var body: some View {
        HStack(spacing: 8) {
            Text(feed.title.isEmpty ? "Untitled feed" : feed.title)
                .font(.headline)
                .lineLimit(1)
            Spacer(minLength: 8)
            let unread = appState.unreadCount(for: feed.id)
            if unread > 0 {
                Text("\(unread) unread")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            if let summary = appState.lastRefreshSummary {
                Text(summary)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Material.bar)
    }
}

private struct ItemRow: View {
    let item: FeedItem
    let density: ListDensity
    let onToggleRead: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            VStack(alignment: .leading, spacing: density == .compact ? 1 : 3) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    if !item.isRead {
                        Circle()
                            .fill(Color.accentColor)
                            .frame(width: density == .compact ? 6 : 7, height: density == .compact ? 6 : 7)
                            .accessibilityHidden(true)
                    }
                    Text(item.title)
                        .font((density == .compact ? Font.callout : Font.body).weight(item.isRead ? .regular : .semibold))
                        .foregroundStyle(item.isRead ? .secondary : .primary)
                        .lineLimit(density == .compact ? 1 : 2)
                    if density == .compact {
                        Spacer(minLength: 6)
                        meta
                    }
                }
                if density == .comfortable, let snippet = Self.plainSnippet(item.summary) {
                    Text(snippet)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                if density == .comfortable {
                    meta
                }
            }
            Button(action: onToggleRead) {
                Image(systemName: item.isRead ? "circle" : "checkmark.circle.fill")
                    .symbolRenderingMode(.hierarchical)
            }
            .buttonStyle(.borderless)
            .help(item.isRead ? "Mark unread" : "Mark read")
            .accessibilityLabel(item.isRead ? "Mark unread" : "Mark read")
        }
        .padding(.vertical, density == .compact ? 0 : 1)
    }

    @ViewBuilder
    private var meta: some View {
        if let published = item.publishedAt {
            Text(Self.relative.localizedString(for: published, relativeTo: Date()))
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .lineLimit(1)
        } else if let link = item.link {
            Text(link)
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .lineLimit(1)
        }
    }

    /// One-line plain excerpt so comfortable rows carry content without opening the article.
    static func plainSnippet(_ summary: String?, limit: Int = 110) -> String? {
        guard var s = summary else { return nil }
        s = s.replacingOccurrences(of: "<[^>]+>", with: " ", options: .regularExpression)
        let entities = [
            "&nbsp;": " ", "&amp;": "&", "&lt;": "<", "&gt;": ">",
            "&quot;": "\"", "&#39;": "'", "&apos;": "'",
        ]
        for (token, value) in entities {
            s = s.replacingOccurrences(of: token, with: value)
        }
        s = s.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        s = s.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !s.isEmpty else { return nil }
        if s.count <= limit { return s }
        let end = s.index(s.startIndex, offsetBy: limit)
        return String(s[..<end]).trimmingCharacters(in: .whitespaces) + "…"
    }

    private static let relative: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter
    }()
}
