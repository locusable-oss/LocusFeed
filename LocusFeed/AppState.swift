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
    @Published var launchBehavior: LaunchBehavior = AppSettings.launchBehavior
    @Published var bodyFontSize: BodyFontSize = AppSettings.bodyFontSize
    @Published var listDensity: ListDensity = AppSettings.listDensity
    @Published var unreadOnly: Bool = AppSettings.unreadOnly
    /// Source-level unread counts. Missing key means zero unread for that feed.
    @Published var unreadByFeed: [String: Int] = [:]

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

    var totalUnread: Int {
        unreadByFeed.values.reduce(0, +)
    }

    func unreadCount(for feedID: String) -> Int {
        unreadByFeed[feedID] ?? 0
    }

    init() {
        do {
            store = try FeedStore()
            reload()
            restartRefreshTimer()
            applyLaunchBehavior()
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
            refreshUnreadCounts()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func refreshUnreadCounts() {
        guard let store else { return }
        do {
            unreadByFeed = try store.unreadCountsByFeed()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func reloadItems() {
        guard let store else { return }
        do {
            items = try store.listItems(feedID: selectedFeedID, unreadOnly: unreadOnly)
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
        guard let id else {
            selectedItemID = nil
            return
        }
        // A quick-mark that already removed the row can echo a stale selection.
        guard items.contains(where: { $0.id == id }) else { return }
        let changed = id != selectedItemID
        selectedItemID = id
        guard changed, let item = items.first(where: { $0.id == id }), !item.isRead else { return }
        setItemRead(id: id, isRead: true)
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
        let successor = nextVisibleID(after: id)
        do {
            try store.setItemRead(id: id, isRead: isRead)
            refreshUnreadCounts()
            if let idx = items.firstIndex(where: { $0.id == id }) {
                items[idx].isRead = isRead
            }
            if unreadOnly && isRead {
                items.removeAll { $0.id == id }
            } else if items.contains(where: { $0.id == id }) {
                sortVisibleItems()
            }
            if let selected = selectedItemID, !items.contains(where: { $0.id == selected }) {
                if let successor, items.contains(where: { $0.id == successor }) {
                    selectedItemID = successor
                } else {
                    selectedItemID = items.first?.id
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

    /// Mark the selection read (if needed) and highlight the next unread item without marking it.
    func markReadAndAdvance() {
        guard let current = selectedItemID else {
            selectedItemID = items.first(where: { !$0.isRead })?.id ?? items.first?.id
            return
        }
        let upcoming = nextUnreadID(after: current)
        if items.first(where: { $0.id == current })?.isRead == false {
            setItemRead(id: current, isRead: true)
        }
        if let upcoming, items.contains(where: { $0.id == upcoming && !$0.isRead }) {
            selectedItemID = upcoming
        }
    }

    func setListDensity(_ density: ListDensity) {
        listDensity = density
        AppSettings.listDensity = density
    }

    func cycleDensity() {
        setListDensity(listDensity == .compact ? .comfortable : .compact)
    }

    func setUnreadOnly(_ flag: Bool) {
        unreadOnly = flag
        AppSettings.unreadOnly = flag
        reloadItems()
    }

    private func sortVisibleItems() {
        items.sort {
            if $0.isRead != $1.isRead { return !$0.isRead && $1.isRead }
            let a = $0.publishedAt ?? $0.createdAt
            let b = $1.publishedAt ?? $1.createdAt
            return a > b
        }
    }

    private func nextVisibleID(after id: String) -> String? {
        guard let idx = items.firstIndex(where: { $0.id == id }) else { return items.first?.id }
        let next = items.index(after: idx)
        if next < items.endIndex { return items[next].id }
        if idx > items.startIndex { return items[items.index(before: idx)].id }
        return nil
    }

    private func nextUnreadID(after id: String) -> String? {
        guard let idx = items.firstIndex(where: { $0.id == id }) else {
            return items.first(where: { !$0.isRead })?.id
        }
        if let later = items[(idx + 1)...].first(where: { !$0.isRead }) {
            return later.id
        }
        return items[..<idx].first(where: { !$0.isRead })?.id
    }

    /// Mark all items in the currently selected feed as read.
    func markSelectedFeedAllRead() {
        guard let store, let feedID = selectedFeedID else { return }
        do {
            try store.markAllRead(feedID: feedID)
            reloadItems()
            refreshUnreadCounts()
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
            refreshUnreadCounts()
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

    func setLaunchBehavior(_ behavior: LaunchBehavior) {
        launchBehavior = behavior
        AppSettings.launchBehavior = behavior
    }

    func setBodyFontSize(_ size: BodyFontSize) {
        bodyFontSize = size
        AppSettings.bodyFontSize = size
    }

    /// Runs only from the production init so tests that inject a store do not fetch the network.
    private func applyLaunchBehavior() {
        switch launchBehavior {
        case .openOnly:
            break
        case .refreshOnLaunch:
            refreshAll()
        case .focusFirstUnread:
            focusFirstUnreadItem()
        }
    }

    /// Jump to the first feed that still has unread items and highlight the newest unread
    /// row without marking it read (selectItem would mark it).
    private func focusFirstUnreadItem() {
        guard let feedID = feeds.first(where: { unreadCount(for: $0.id) > 0 })?.id else { return }
        if feedID != selectedFeedID {
            selectedFeedID = feedID
            selectedItemID = nil
            reloadItems()
        }
        if let unreadID = items.first(where: { !$0.isRead })?.id {
            selectedItemID = unreadID
        }
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
