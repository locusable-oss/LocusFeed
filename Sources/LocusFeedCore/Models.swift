import Foundation

public struct Feed: Identifiable, Equatable, Sendable, Hashable {
    public var id: String
    public var title: String
    public var url: String
    public var siteURL: String?
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        id: String = UUID().uuidString,
        title: String,
        url: String,
        siteURL: String? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.url = url
        self.siteURL = siteURL
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

public struct FeedItem: Identifiable, Equatable, Sendable, Hashable {
    public var id: String
    public var feedID: String
    public var title: String
    public var link: String?
    public var summary: String?
    public var publishedAt: Date?
    public var isRead: Bool
    public var createdAt: Date

    public init(
        id: String = UUID().uuidString,
        feedID: String,
        title: String,
        link: String? = nil,
        summary: String? = nil,
        publishedAt: Date? = nil,
        isRead: Bool = false,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.feedID = feedID
        self.title = title
        self.link = link
        self.summary = summary
        self.publishedAt = publishedAt
        self.isRead = isRead
        self.createdAt = createdAt
    }
}
