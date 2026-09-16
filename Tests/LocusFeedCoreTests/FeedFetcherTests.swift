import XCTest
@testable import LocusFeedCore

final class FeedFetcherTests: XCTestCase {
    func testParseRSS20() throws {
        let xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <rss version="2.0">
          <channel>
            <title>Example Feed</title>
            <item>
              <title>Hello</title>
              <link>https://example.com/1</link>
              <guid>https://example.com/1</guid>
              <pubDate>Mon, 01 Jan 2024 12:00:00 +0000</pubDate>
              <description>Body</description>
            </item>
            <item>
              <title>Second</title>
              <link>https://example.com/2</link>
              <guid isPermaLink="false">abc-2</guid>
            </item>
          </channel>
        </rss>
        """
        let parsed = try FeedFetcher.parse(data: Data(xml.utf8))
        XCTAssertEqual(parsed.title, "Example Feed")
        XCTAssertEqual(parsed.items.count, 2)
        XCTAssertEqual(parsed.items[0].title, "Hello")
        XCTAssertEqual(parsed.items[0].link, "https://example.com/1")
        XCTAssertEqual(parsed.items[0].guid, "https://example.com/1")
        XCTAssertNotNil(parsed.items[0].publishedAt)
        XCTAssertEqual(parsed.items[1].guid, "abc-2")
    }

    func testParseAtom() throws {
        let xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <feed xmlns="http://www.w3.org/2005/Atom">
          <title>Atom Feed</title>
          <entry>
            <title>Entry One</title>
            <id>urn:example:1</id>
            <link rel="alternate" href="https://example.com/a"/>
            <published>2024-06-15T10:30:00Z</published>
            <summary>Sum</summary>
          </entry>
        </feed>
        """
        let parsed = try FeedFetcher.parse(data: Data(xml.utf8))
        XCTAssertEqual(parsed.title, "Atom Feed")
        XCTAssertEqual(parsed.items.count, 1)
        XCTAssertEqual(parsed.items[0].guid, "urn:example:1")
        XCTAssertEqual(parsed.items[0].link, "https://example.com/a")
        XCTAssertNotNil(parsed.items[0].publishedAt)
    }

    func testRejectNonHTTPS() async {
        let fetcher = FeedFetcher()
        do {
            _ = try await fetcher.download(urlString: "http://example.com/feed.xml")
            XCTFail("expected notHTTPS")
        } catch let e as FeedFetcherError {
            XCTAssertEqual(e, .notHTTPS("http://example.com/feed.xml"))
        } catch {
            XCTFail("unexpected \(error)")
        }
    }

    func testFetchInsertsUnreadAndPreservesRead() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: dir) }
        let store = try FeedStore(directory: dir)
        let feed = try store.addFeed(title: "T", url: "https://example.com/feed.xml")

        let xml = """
        <?xml version="1.0"?><rss version="2.0"><channel><title>T</title>
        <item><title>A</title><guid>g1</guid><link>https://example.com/a</link></item>
        </channel></rss>
        """
        let parsed = try FeedFetcher.parse(data: Data(xml.utf8))
        let id = FeedFetcher.itemID(feedID: feed.id, guid: parsed.items[0].guid)
        _ = try store.upsertItem(FeedItem(id: id, feedID: feed.id, title: "A", link: "https://example.com/a", isRead: false))
        XCTAssertFalse(try store.listItems(feedID: feed.id)[0].isRead)

        // Mark read then upsert again — read state must stick.
        try store.setItemRead(id: id, isRead: true)
        _ = try store.upsertItem(FeedItem(id: id, feedID: feed.id, title: "A updated", link: "https://example.com/a", isRead: false))
        let after = try store.listItems(feedID: feed.id)[0]
        XCTAssertEqual(after.title, "A updated")
        XCTAssertTrue(after.isRead)
    }
}
