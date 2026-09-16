import Foundation
import SwiftUI

@MainActor
final class AppState: ObservableObject {
    @Published var feeds: [Feed] = []
    @Published var items: [FeedItem] = []
    @Published var selectedFeedID: Feed.ID?
    @Published var errorMessage: String?
    @Published var presentAddFeed = false
    @Published var editingFeed: Feed?
    @Published var isRefreshing = false
    @Published var lastRefreshSummary: String?

    private var store: FeedStore?
    private let fetcher = FeedFetcher()

    init() {
        do {
            store = try FeedStore()
            reload()
        } catch {
            errorMessage = "Store open failed: \(error.localizedDescription)"
        }
    }

    /// Test / preview hook.
    init(store: FeedStore) {
        self.store = store
        reload()
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
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func selectFeed(id: Feed.ID?) {
        selectedFeedID = id
        reloadItems()
    }

    func addFeed(title: String, url: String, siteURL: String?) {
        guard let store else { return }
        do {
            let feed = try store.addFeed(title: title, url: url, siteURL: siteURL)
            reload()
            selectedFeedID = feed.id
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

    /// Fetch + parse every subscribed feed; surface per-feed failures in the error alert.
    func refreshAll() {
        guard let store else { return }
        guard !isRefreshing else { return }
        isRefreshing = true
        lastRefreshSummary = nil
        Task { @MainActor in
            defer { isRefreshing = false }
            var failures: [String] = []
            var insertedTotal = 0
            var updatedTotal = 0
            let snapshot = feeds
            for feed in snapshot {
                do {
                    let result = try await fetcher.fetchAndStore(feed: feed, store: store)
                    insertedTotal += result.insertedCount
                    updatedTotal += result.updatedCount
                } catch {
                    let label = feed.title.isEmpty ? feed.url : feed.title
                    failures.append("\(label): \(error.localizedDescription)")
                }
            }
            reload()
            lastRefreshSummary = "New \(insertedTotal), updated \(updatedTotal)"
            if !failures.isEmpty {
                errorMessage = failures.joined(separator: "\n")
            }
        }
    }
}
