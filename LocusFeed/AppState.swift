import Foundation
import SwiftUI

@MainActor
final class AppState: ObservableObject {
    @Published var feeds: [Feed] = []
    @Published var items: [FeedItem] = []
    @Published var selectedFeedID: Feed.ID?
    @Published var selectedItemID: FeedItem.ID?
    @Published var errorMessage: String?
    @Published var presentAddFeed = false
    @Published var editingFeed: Feed?
    @Published var isRefreshing = false
    @Published var lastRefreshSummary: String?
    @Published var refreshIntervalMinutes: Int = AppSettings.refreshIntervalMinutes

    private var store: FeedStore?
    private let fetcher = FeedFetcher()
    private var refreshTimer: Timer?

    var selectedItem: FeedItem? {
        guard let selectedItemID else { return nil }
        return items.first(where: { $0.id == selectedItemID })
    }

    var selectedFeed: Feed? {
        guard let selectedFeedID else { return nil }
        return feeds.first(where: { $0.id == selectedFeedID })
    }

    init() {
        do {
            store = try FeedStore()
            reload()
            restartRefreshTimer()
        } catch {
            errorMessage = "Store open failed: \(error.localizedDescription)"
        }
    }

    /// Test / preview hook.
    init(store: FeedStore) {
        self.store = store
        reload()
    }

    deinit {
        refreshTimer?.invalidate()
    }

    func reload() {
        guard let store else { return }
        do {
            feeds = try store.listFeeds()
            if let selectedFeedID, !feeds.contains(where: { $0.id == selectedFeedID }) {
                self.selectedFeedID = feeds.first?.id
            } else if selectedFeedID == nil {
                selectedFeedID = feeds.first?.id
            }
            reloadItems()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func reloadItems() {
        guard let store else { return }
        do {
            items = try store.listItems(feedID: selectedFeedID)
            if let selectedItemID, !items.contains(where: { $0.id == selectedItemID }) {
                self.selectedItemID = items.first?.id
            } else if selectedItemID == nil {
                selectedItemID = items.first?.id
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func selectFeed(id: Feed.ID?) {
        selectedFeedID = id
        selectedItemID = nil
        reloadItems()
    }

    func selectItem(id: FeedItem.ID?) {
        selectedItemID = id
        if let id, let item = items.first(where: { $0.id == id }), !item.isRead {
            setItemRead(id: id, isRead: true)
        }
    }

    func addFeed(title: String, url: String, siteURL: String?) {
        guard let store else { return }
        do {
            let feed = try store.addFeed(title: title, url: url, siteURL: siteURL)
            reload()
            selectedFeedID = feed.id
            selectedItemID = nil
            reloadItems()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func updateFeed(_ feed: Feed) {
        guard let store else { return }
        do {
            try store.updateFeed(feed)
            reload()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func deleteFeed(id: String) {
        guard let store else { return }
        do {
            try store.deleteFeed(id: id)
            reload()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Read / unread state machine

    func setItemRead(id: String, isRead: Bool) {
        guard let store else { return }
        do {
            try store.setItemRead(id: id, isRead: isRead)
            if let idx = items.firstIndex(where: { $0.id == id }) {
                items[idx].isRead = isRead
                // Keep unread-first ordering in the UI list.
                items.sort {
                    if $0.isRead != $1.isRead { return !$0.isRead && $1.isRead }
                    let a = $0.publishedAt ?? $0.createdAt
                    let b = $1.publishedAt ?? $1.createdAt
                    return a > b
                }
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func toggleItemRead(id: String) {
        guard let item = items.first(where: { $0.id == id }) else { return }
        setItemRead(id: id, isRead: !item.isRead)
    }

    /// Mark all items in the currently selected feed as read.
    func markSelectedFeedAllRead() {
        guard let store, let feedID = selectedFeedID else { return }
        do {
            try store.markAllRead(feedID: feedID)
            reloadItems()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Mark every item across all feeds as read.
    func markAllFeedsRead() {
        guard let store else { return }
        do {
            try store.markAllRead(feedID: nil)
            reloadItems()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Refresh (manual + timed)

    /// Fetch + parse every subscribed feed; surface per-feed failures in the error alert.
    func refreshAll() {
        guard let store else { return }
        guard !isRefreshing else { return }
        isRefreshing = true
        lastRefreshSummary = nil
        Task { @MainActor in
            defer { isRefreshing = false }
            let snapshot = feeds
            let result = await fetcher.refreshAll(feeds: snapshot, store: store)
            reload()
            lastRefreshSummary = "New \(result.inserted), updated \(result.updated)"
            if !result.failures.isEmpty {
                errorMessage = result.failures.map { pair in
                    let label = pair.feed.title.isEmpty ? pair.feed.url : pair.feed.title
                    return "\(label): \(pair.message)"
                }.joined(separator: "\n")
            }
        }
    }

    func setRefreshIntervalMinutes(_ minutes: Int) {
        let clamped = max(0, minutes)
        refreshIntervalMinutes = clamped
        AppSettings.refreshIntervalMinutes = clamped
        restartRefreshTimer()
    }

    func restartRefreshTimer() {
        refreshTimer?.invalidate()
        refreshTimer = nil
        let minutes = refreshIntervalMinutes
        guard minutes > 0 else { return }
        let interval = TimeInterval(minutes * 60)
        let timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.refreshAll()
            }
        }
        timer.tolerance = min(30, interval * 0.1)
        RunLoop.main.add(timer, forMode: .common)
        refreshTimer = timer
    }
}
