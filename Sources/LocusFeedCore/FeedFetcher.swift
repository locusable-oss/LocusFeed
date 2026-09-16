import Foundation

public enum FeedFetcherError: Error, LocalizedError, Equatable {
    case invalidURL(String)
    case notHTTPS(String)
    case network(String)
    case httpStatus(Int)
    case emptyBody
    case parseFailed(String)
    case unsupportedFormat

    public var errorDescription: String? {
        switch self {
        case .invalidURL(let s): return "Invalid feed URL: \(s)"
        case .notHTTPS(let s): return "Only HTTPS feed URLs are supported: \(s)"
        case .network(let s): return "Network error: \(s)"
        case .httpStatus(let c): return "Feed server returned HTTP \(c)"
        case .emptyBody: return "Feed response was empty"
        case .parseFailed(let s): return "Could not parse feed: \(s)"
        case .unsupportedFormat: return "Unsupported feed format (need RSS 2.0 or Atom)"
        }
    }
}

public struct ParsedFeedItem: Equatable, Sendable {
    public var guid: String
    public var title: String
    public var link: String?
    public var publishedAt: Date?
    public var summary: String?

    public init(guid: String, title: String, link: String? = nil, publishedAt: Date? = nil, summary: String? = nil) {
        self.guid = guid
        self.title = title
        self.link = link
        self.publishedAt = publishedAt
        self.summary = summary
    }
}

public struct ParsedFeed: Equatable, Sendable {
    public var title: String?
    public var items: [ParsedFeedItem]

    public init(title: String? = nil, items: [ParsedFeedItem]) {
        self.title = title
        self.items = items
    }
}

public struct FeedFetchResult: Equatable, Sendable {
    public var parsed: ParsedFeed
    public var insertedCount: Int
    public var updatedCount: Int

    public init(parsed: ParsedFeed, insertedCount: Int, updatedCount: Int) {
        self.parsed = parsed
        self.insertedCount = insertedCount
        self.updatedCount = updatedCount
    }
}

/// Fetches an HTTPS feed URL and minimally parses RSS 2.0 / Atom into items.
public struct FeedFetcher: Sendable {
    public var session: URLSession
    public var userAgent: String

    public init(session: URLSession = .shared, userAgent: String = "LocusFeed/0.1 (+https://github.com/locusable-oss/LocusFeed)") {
        self.session = session
        self.userAgent = userAgent
    }

    /// Stable item primary key: feed-scoped so GUIDs do not collide across subscriptions.
    public static func itemID(feedID: String, guid: String) -> String {
        "\(feedID)::\(guid)"
    }

    public func fetchAndStore(feed: Feed, store: FeedStore) async throws -> FeedFetchResult {
        let data = try await download(urlString: feed.url)
        let parsed = try Self.parse(data: data)
        var inserted = 0
        var updated = 0
        for raw in parsed.items {
            let guid = raw.guid.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !guid.isEmpty else { continue }
            let id = Self.itemID(feedID: feed.id, guid: guid)
            let existed = try store.itemExists(id: id)
            let item = FeedItem(
                id: id,
                feedID: feed.id,
                title: raw.title.isEmpty ? "(untitled)" : raw.title,
                link: raw.link,
                summary: raw.summary,
                publishedAt: raw.publishedAt,
                isRead: false
            )
            _ = try store.upsertItem(item)
            if existed { updated += 1 } else { inserted += 1 }
        }
        return FeedFetchResult(parsed: parsed, insertedCount: inserted, updatedCount: updated)
    }

    public func download(urlString: String) async throws -> Data {
        let trimmed = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmed), let scheme = url.scheme?.lowercased() else {
            throw FeedFetcherError.invalidURL(trimmed)
        }
        guard scheme == "https" else {
            throw FeedFetcherError.notHTTPS(trimmed)
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = 30
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        request.setValue("application/rss+xml, application/atom+xml, application/xml, text/xml, */*;q=0.8", forHTTPHeaderField: "Accept")

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw FeedFetcherError.network(error.localizedDescription)
        }

        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw FeedFetcherError.httpStatus(http.statusCode)
        }
        guard !data.isEmpty else { throw FeedFetcherError.emptyBody }
        return data
    }

    public static func parse(data: Data) throws -> ParsedFeed {
        let parser = FeedXMLParser()
        return try parser.parse(data: data)
    }
}

// MARK: - XML

private final class FeedXMLParser: NSObject, XMLParserDelegate {
    private enum Kind { case unknown, rss, atom }

    private var kind: Kind = .unknown
    private var feedTitle: String?
    private var items: [ParsedFeedItem] = []

    private var path: [String] = []
    private var textBuffer = ""

    private var curTitle: String?
    private var curLink: String?
    private var curGuid: String?
    private var curDate: Date?
    private var curSummary: String?
    private var atomLinkHref: String?
    private var atomLinkRel: String?

    private var fatalMessage: String?

    func parse(data: Data) throws -> ParsedFeed {
        let xp = XMLParser(data: data)
        xp.delegate = self
        xp.shouldProcessNamespaces = false
        guard xp.parse() else {
            let msg = xp.parserError?.localizedDescription ?? fatalMessage ?? "XML parse failed"
            throw FeedFetcherError.parseFailed(msg)
        }
        if let fatalMessage { throw FeedFetcherError.parseFailed(fatalMessage) }
        guard kind != .unknown else { throw FeedFetcherError.unsupportedFormat }
        return ParsedFeed(title: feedTitle, items: items)
    }

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String: String] = [:]) {
        let name = elementName.lowercased()
        path.append(name)
        textBuffer = ""

        if path.count == 1 {
            if name == "rss" { kind = .rss }
            else if name == "feed" { kind = .atom }
        }

        if kind == .rss, name == "item" {
            resetItem()
        }
        if kind == .atom, name == "entry" {
            resetItem()
        }

        if kind == .atom, name == "link", inEntry {
            atomLinkHref = attributeDict["href"]
            atomLinkRel = attributeDict["rel"]?.lowercased()
            // Prefer rel=alternate or missing rel as the entry link.
            if atomLinkRel == nil || atomLinkRel == "alternate" {
                if let href = atomLinkHref, !href.isEmpty {
                    curLink = href
                }
            } else if curLink == nil, let href = atomLinkHref, !href.isEmpty {
                curLink = href
            }
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        textBuffer += string
    }

    func parser(_ parser: XMLParser, foundCDATA CDATABlock: Data) {
        if let s = String(data: CDATABlock, encoding: .utf8) {
            textBuffer += s
        }
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        let name = elementName.lowercased()
        let text = textBuffer.trimmingCharacters(in: .whitespacesAndNewlines)

        if kind == .rss {
            if inChannel, !inItem {
                if name == "title", feedTitle == nil, !text.isEmpty { feedTitle = text }
            }
            if inItem {
                switch name {
                case "title": curTitle = text
                case "link": if !text.isEmpty { curLink = text }
                case "guid": curGuid = text
                case "pubdate": curDate = Self.parseRSSDate(text)
                case "description": curSummary = text
                case "item":
                    finishItem()
                default: break
                }
            }
        } else if kind == .atom {
            if inFeed, !inEntry {
                if name == "title", feedTitle == nil, !text.isEmpty { feedTitle = text }
            }
            if inEntry {
                switch name {
                case "title": curTitle = text
                case "id": curGuid = text
                case "published", "updated":
                    if let d = Self.parseAtomDate(text) {
                        // Prefer published; keep first non-nil, or overwrite updated only if published missing.
                        if name == "published" || curDate == nil { curDate = d }
                    }
                case "summary", "content":
                    if curSummary == nil || name == "summary" { curSummary = text }
                case "entry":
                    finishItem()
                default: break
                }
            }
        }

        if !path.isEmpty { path.removeLast() }
        textBuffer = ""
    }

    func parser(_ parser: XMLParser, parseErrorOccurred parseError: Error) {
        fatalMessage = parseError.localizedDescription
    }

    private var inChannel: Bool { path.contains("channel") }
    private var inItem: Bool { path.contains("item") }
    private var inFeed: Bool { path.first == "feed" }
    private var inEntry: Bool { path.contains("entry") }

    private func resetItem() {
        curTitle = nil
        curLink = nil
        curGuid = nil
        curDate = nil
        curSummary = nil
        atomLinkHref = nil
        atomLinkRel = nil
    }

    private func finishItem() {
        let title = (curTitle ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        var guid = (curGuid ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if guid.isEmpty, let link = curLink, !link.isEmpty { guid = link }
        if guid.isEmpty, !title.isEmpty { guid = title }
        guard !guid.isEmpty else {
            resetItem()
            return
        }
        items.append(ParsedFeedItem(
            guid: guid,
            title: title.isEmpty ? "(untitled)" : title,
            link: curLink,
            publishedAt: curDate,
            summary: curSummary
        ))
        resetItem()
    }

    private static let rssDateFormatters: [DateFormatter] = {
        let formats = [
            "EEE, dd MMM yyyy HH:mm:ss Z",
            "EEE, dd MMM yyyy HH:mm:ss zzz",
            "dd MMM yyyy HH:mm:ss Z",
        ]
        return formats.map { fmt in
            let f = DateFormatter()
            f.locale = Locale(identifier: "en_US_POSIX")
            f.dateFormat = fmt
            return f
        }
    }()

    private static func parseRSSDate(_ s: String) -> Date? {
        for f in rssDateFormatters {
            if let d = f.date(from: s) { return d }
        }
        return nil
    }

    private static let isoFractional: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    private static let isoBasic: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    private static func parseAtomDate(_ s: String) -> Date? {
        if let d = isoFractional.date(from: s) { return d }
        if let d = isoBasic.date(from: s) { return d }
        return parseRSSDate(s)
    }
}
