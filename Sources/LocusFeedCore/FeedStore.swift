import Foundation
import SQLite3

public enum FeedStoreError: Error, LocalizedError {
    case openFailed(String)
    case prepareFailed(String)
    case stepFailed(String)
    case notFound

    public var errorDescription: String? {
        switch self {
        case .openFailed(let m), .prepareFailed(let m), .stepFailed(let m): return m
        case .notFound: return "Not found"
        }
    }
}

/// Local SQLite persistence for subscription feeds and items (Application Support).
public final class FeedStore: @unchecked Sendable {
    private var db: OpaquePointer?
    private let path: String

    public init(directory: URL? = nil) throws {
        let dir = try directory ?? Self.defaultDirectory()
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        path = dir.appendingPathComponent("locusfeed.sqlite").path
        try open()
        try migrate()
    }

    deinit {
        if db != nil { sqlite3_close(db) }
    }

    public static func defaultDirectory() throws -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return base.appendingPathComponent("studio.locusable.LocusFeed", isDirectory: true)
    }

    // MARK: - Feeds CRUD

    public func listFeeds() throws -> [Feed] {
        let sql = "SELECT id, title, url, site_url, created_at, updated_at FROM feeds ORDER BY title COLLATE NOCASE;"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            throw FeedStoreError.prepareFailed(errmsg())
        }
        defer { sqlite3_finalize(stmt) }
        var rows: [Feed] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            rows.append(feed(from: stmt!))
        }
        return rows
    }

    public func feed(id: String) throws -> Feed? {
        let sql = "SELECT id, title, url, site_url, created_at, updated_at FROM feeds WHERE id = ? LIMIT 1;"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            throw FeedStoreError.prepareFailed(errmsg())
        }
        defer { sqlite3_finalize(stmt) }
        bindText(stmt, 1, id)
        if sqlite3_step(stmt) == SQLITE_ROW { return feed(from: stmt!) }
        return nil
    }

    @discardableResult
    public func addFeed(title: String, url: String, siteURL: String? = nil) throws -> Feed {
        let feed = Feed(title: title.trimmingCharacters(in: .whitespacesAndNewlines),
                        url: url.trimmingCharacters(in: .whitespacesAndNewlines),
                        siteURL: siteURL?.trimmingCharacters(in: .whitespacesAndNewlines))
        let sql = """
        INSERT INTO feeds (id, title, url, site_url, created_at, updated_at)
        VALUES (?, ?, ?, ?, ?, ?);
        """
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            throw FeedStoreError.prepareFailed(errmsg())
        }
        defer { sqlite3_finalize(stmt) }
        bindText(stmt, 1, feed.id)
        bindText(stmt, 2, feed.title)
        bindText(stmt, 3, feed.url)
        bindText(stmt, 4, feed.siteURL)
        bindDouble(stmt, 5, feed.createdAt.timeIntervalSince1970)
        bindDouble(stmt, 6, feed.updatedAt.timeIntervalSince1970)
        guard sqlite3_step(stmt) == SQLITE_DONE else { throw FeedStoreError.stepFailed(errmsg()) }
        return feed
    }

    public func updateFeed(_ feed: Feed) throws {
        let sql = """
        UPDATE feeds SET title = ?, url = ?, site_url = ?, updated_at = ? WHERE id = ?;
        """
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            throw FeedStoreError.prepareFailed(errmsg())
        }
        defer { sqlite3_finalize(stmt) }
        let now = Date()
        bindText(stmt, 1, feed.title)
        bindText(stmt, 2, feed.url)
        bindText(stmt, 3, feed.siteURL)
        bindDouble(stmt, 4, now.timeIntervalSince1970)
        bindText(stmt, 5, feed.id)
        guard sqlite3_step(stmt) == SQLITE_DONE else { throw FeedStoreError.stepFailed(errmsg()) }
        if sqlite3_changes(db) == 0 { throw FeedStoreError.notFound }
    }

    public func deleteFeed(id: String) throws {
        // Cascade items first (explicit; also covered by FK if enabled)
        try exec("DELETE FROM items WHERE feed_id = '\(escape(id))';")
        try exec("DELETE FROM feeds WHERE id = '\(escape(id))';")
    }

    // MARK: - Items (model + insert for later fetch sorts)

    public func listItems(feedID: String? = nil, unreadOnly: Bool = false) throws -> [FeedItem] {
        var sql = "SELECT id, feed_id, title, link, summary, published_at, is_read, created_at FROM items"
        var clauses: [String] = []
        if let feedID { clauses.append("feed_id = '\(escape(feedID))'") }
        if unreadOnly { clauses.append("is_read = 0") }
        if !clauses.isEmpty { sql += " WHERE " + clauses.joined(separator: " AND ") }
        sql += " ORDER BY COALESCE(published_at, created_at) DESC;"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            throw FeedStoreError.prepareFailed(errmsg())
        }
        defer { sqlite3_finalize(stmt) }
        var rows: [FeedItem] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            rows.append(item(from: stmt!))
        }
        return rows
    }

    public func setItemRead(id: String, isRead: Bool) throws {
        let sql = "UPDATE items SET is_read = ? WHERE id = ?;"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            throw FeedStoreError.prepareFailed(errmsg())
        }
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_int(stmt, 1, isRead ? 1 : 0)
        bindText(stmt, 2, id)
        guard sqlite3_step(stmt) == SQLITE_DONE else { throw FeedStoreError.stepFailed(errmsg()) }
        if sqlite3_changes(db) == 0 { throw FeedStoreError.notFound }
    }

    public func itemExists(id: String) throws -> Bool {
        let sql = "SELECT 1 FROM items WHERE id = ? LIMIT 1;"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            throw FeedStoreError.prepareFailed(errmsg())
        }
        defer { sqlite3_finalize(stmt) }
        bindText(stmt, 1, id)
        return sqlite3_step(stmt) == SQLITE_ROW
    }

    @discardableResult
    public func upsertItem(_ item: FeedItem) throws -> FeedItem {
        let sql = """
        INSERT INTO items (id, feed_id, title, link, summary, published_at, is_read, created_at)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?)
        ON CONFLICT(id) DO UPDATE SET
          title = excluded.title,
          link = excluded.link,
          summary = excluded.summary,
          published_at = excluded.published_at;
        """
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            throw FeedStoreError.prepareFailed(errmsg())
        }
        defer { sqlite3_finalize(stmt) }
        bindText(stmt, 1, item.id)
        bindText(stmt, 2, item.feedID)
        bindText(stmt, 3, item.title)
        bindText(stmt, 4, item.link)
        bindText(stmt, 5, item.summary)
        if let p = item.publishedAt {
            bindDouble(stmt, 6, p.timeIntervalSince1970)
        } else {
            sqlite3_bind_null(stmt, 6)
        }
        sqlite3_bind_int(stmt, 7, item.isRead ? 1 : 0)
        bindDouble(stmt, 8, item.createdAt.timeIntervalSince1970)
        guard sqlite3_step(stmt) == SQLITE_DONE else { throw FeedStoreError.stepFailed(errmsg()) }
        return item
    }

    // MARK: - Private

    private func open() throws {
        if sqlite3_open(path, &db) != SQLITE_OK {
            throw FeedStoreError.openFailed(errmsg())
        }
        sqlite3_exec(db, "PRAGMA foreign_keys = ON;", nil, nil, nil)
    }

    private func migrate() throws {
        try exec("""
        CREATE TABLE IF NOT EXISTS feeds (
          id TEXT PRIMARY KEY NOT NULL,
          title TEXT NOT NULL,
          url TEXT NOT NULL UNIQUE,
          site_url TEXT,
          created_at REAL NOT NULL,
          updated_at REAL NOT NULL
        );
        """)
        try exec("""
        CREATE TABLE IF NOT EXISTS items (
          id TEXT PRIMARY KEY NOT NULL,
          feed_id TEXT NOT NULL REFERENCES feeds(id) ON DELETE CASCADE,
          title TEXT NOT NULL,
          link TEXT,
          summary TEXT,
          published_at REAL,
          is_read INTEGER NOT NULL DEFAULT 0,
          created_at REAL NOT NULL
        );
        """)
        try exec("CREATE INDEX IF NOT EXISTS idx_items_feed ON items(feed_id);")
        try exec("CREATE INDEX IF NOT EXISTS idx_items_unread ON items(is_read, published_at);")
    }

    private func exec(_ sql: String) throws {
        if sqlite3_exec(db, sql, nil, nil, nil) != SQLITE_OK {
            throw FeedStoreError.stepFailed(errmsg())
        }
    }

    private func errmsg() -> String {
        String(cString: sqlite3_errmsg(db))
    }

    private func escape(_ s: String) -> String {
        s.replacingOccurrences(of: "'", with: "''")
    }

    private func bindText(_ stmt: OpaquePointer?, _ idx: Int32, _ value: String?) {
        if let value {
            // SQLITE_TRANSIENT: copy bytes; safe for Swift String lifetimes
            let transient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
            _ = value.withCString { cstr in
                sqlite3_bind_text(stmt, idx, cstr, -1, transient)
            }
        } else {
            sqlite3_bind_null(stmt, idx)
        }
    }

    private func bindDouble(_ stmt: OpaquePointer?, _ idx: Int32, _ value: Double) {
        sqlite3_bind_double(stmt, idx, value)
    }

    private func text(_ stmt: OpaquePointer, _ idx: Int32) -> String {
        guard let c = sqlite3_column_text(stmt, idx) else { return "" }
        return String(cString: c)
    }

    private func optionalText(_ stmt: OpaquePointer, _ idx: Int32) -> String? {
        guard sqlite3_column_type(stmt, idx) != SQLITE_NULL,
              let c = sqlite3_column_text(stmt, idx) else { return nil }
        return String(cString: c)
    }

    private func feed(from stmt: OpaquePointer) -> Feed {
        Feed(
            id: text(stmt, 0),
            title: text(stmt, 1),
            url: text(stmt, 2),
            siteURL: optionalText(stmt, 3),
            createdAt: Date(timeIntervalSince1970: sqlite3_column_double(stmt, 4)),
            updatedAt: Date(timeIntervalSince1970: sqlite3_column_double(stmt, 5))
        )
    }

    private func item(from stmt: OpaquePointer) -> FeedItem {
        let published: Date? = sqlite3_column_type(stmt, 5) == SQLITE_NULL
            ? nil
            : Date(timeIntervalSince1970: sqlite3_column_double(stmt, 5))
        return FeedItem(
            id: text(stmt, 0),
            feedID: text(stmt, 1),
            title: text(stmt, 2),
            link: optionalText(stmt, 3),
            summary: optionalText(stmt, 4),
            publishedAt: published,
            isRead: sqlite3_column_int(stmt, 6) != 0,
            createdAt: Date(timeIntervalSince1970: sqlite3_column_double(stmt, 7))
        )
    }
}
