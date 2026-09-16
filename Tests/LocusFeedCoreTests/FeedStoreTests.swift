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
}
