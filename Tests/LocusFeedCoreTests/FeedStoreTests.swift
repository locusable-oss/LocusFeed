import XCTest
@testable import LocusFeedCore

final class FeedStoreTests: XCTestCase {
    func testCRUDRoundTrip() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: dir) }
        let store = try FeedStore(directory: dir)

        let added = try store.addFeed(title: "Example", url: "https://example.com/feed.xml", siteURL: "https://example.com")
        XCTAssertEqual(try store.listFeeds().count, 1)

        var edited = added
        edited.title = "Example News"
        try store.updateFeed(edited)
        XCTAssertEqual(try store.feed(id: added.id)?.title, "Example News")

        _ = try store.upsertItem(FeedItem(feedID: added.id, title: "Hello", link: "https://example.com/1"))
        XCTAssertEqual(try store.listItems(feedID: added.id).count, 1)

        try store.deleteFeed(id: added.id)
        XCTAssertEqual(try store.listFeeds().count, 0)
        XCTAssertEqual(try store.listItems().count, 0)
    }

    func testReadUnreadPersistenceAndUnreadFirstOrder() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: dir) }
        let store = try FeedStore(directory: dir)
        let feed = try store.addFeed(title: "F", url: "https://example.com/f.xml")

        let older = Date(timeIntervalSince1970: 1_000)
        let newer = Date(timeIntervalSince1970: 2_000)
        let a = try store.upsertItem(FeedItem(id: "a", feedID: feed.id, title: "A", publishedAt: older, isRead: false))
        let b = try store.upsertItem(FeedItem(id: "b", feedID: feed.id, title: "B", publishedAt: newer, isRead: false))
        _ = a
        XCTAssertEqual(try store.unreadCount(feedID: feed.id), 2)

        try store.setItemRead(id: b.id, isRead: true)
        XCTAssertTrue(try store.item(id: b.id)?.isRead == true)
        XCTAssertEqual(try store.unreadCount(feedID: feed.id), 1)

        // Unread-first: unread A before read B even though B is newer.
        let ordered = try store.listItems(feedID: feed.id)
        XCTAssertEqual(ordered.map(\.id), ["a", "b"])

        try store.setItemRead(id: a.id, isRead: true)
        try store.setItemRead(id: a.id, isRead: false)
        XCTAssertFalse(try store.item(id: a.id)?.isRead == true)
    }

    func testMarkAllReadFeedAndGlobal() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: dir) }
        let store = try FeedStore(directory: dir)
        let f1 = try store.addFeed(title: "One", url: "https://example.com/1.xml")
        let f2 = try store.addFeed(title: "Two", url: "https://example.com/2.xml")
        _ = try store.upsertItem(FeedItem(id: "i1", feedID: f1.id, title: "I1", isRead: false))
        _ = try store.upsertItem(FeedItem(id: "i2", feedID: f1.id, title: "I2", isRead: false))
        _ = try store.upsertItem(FeedItem(id: "i3", feedID: f2.id, title: "I3", isRead: false))

        try store.markAllRead(feedID: f1.id)
        XCTAssertEqual(try store.unreadCount(feedID: f1.id), 0)
        XCTAssertEqual(try store.unreadCount(feedID: f2.id), 1)

        try store.markAllRead(feedID: nil)
        XCTAssertEqual(try store.unreadCount(feedID: nil), 0)
        XCTAssertTrue(try store.listItems().allSatisfy(\.isRead))
    }

    func testUnreadCountsByFeedOmitsZero() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: dir) }
        let store = try FeedStore(directory: dir)
        let f1 = try store.addFeed(title: "One", url: "https://example.com/1.xml")
        let f2 = try store.addFeed(title: "Two", url: "https://example.com/2.xml")
        let f3 = try store.addFeed(title: "Quiet", url: "https://example.com/3.xml")
        _ = try store.upsertItem(FeedItem(id: "i1", feedID: f1.id, title: "I1", isRead: false))
        _ = try store.upsertItem(FeedItem(id: "i2", feedID: f1.id, title: "I2", isRead: false))
        _ = try store.upsertItem(FeedItem(id: "i3", feedID: f2.id, title: "I3", isRead: true))
        _ = try store.upsertItem(FeedItem(id: "i4", feedID: f2.id, title: "I4", isRead: false))
        _ = f3

        let counts = try store.unreadCountsByFeed()
        XCTAssertEqual(counts[f1.id], 2)
        XCTAssertEqual(counts[f2.id], 1)
        XCTAssertNil(counts[f3.id])
        XCTAssertEqual(counts.values.reduce(0, +), try store.unreadCount())

        try store.setItemRead(id: "i4", isRead: true)
        let after = try store.unreadCountsByFeed()
        XCTAssertNil(after[f2.id])
        XCTAssertEqual(after[f1.id], 2)
    }
}
