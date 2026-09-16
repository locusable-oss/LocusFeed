import Foundation
import SwiftUI

@MainActor
final class AppState: ObservableObject {
    @Published var feeds: [Feed] = []
    @Published var selectedFeedID: Feed.ID?
    @Published var errorMessage: String?
    @Published var presentAddFeed = false
    @Published var editingFeed: Feed?

    private var store: FeedStore?

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
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func addFeed(title: String, url: String, siteURL: String?) {
        guard let store else { return }
        do {
            let feed = try store.addFeed(title: title, url: url, siteURL: siteURL)
            reload()
            selectedFeedID = feed.id
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
}
