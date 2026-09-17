# LocusFeed acceptance (MVP sorts 1–11)

Unsigned local Debug on macOS 15+ with Xcode.

1. **Naming** — App displays as LocusFeed; bundle `studio.locusable.LocusFeed`.
2. **Skeleton** — `make generate && make build` produces a runnable window app (Menu + WindowGroup).
3. **Store** — SQLite file under Application Support stores `feeds` and `items` tables; models compile via LocusFeedCore.
4. **Feed CRUD** — UI can add / edit / delete subscription feeds; rows persist across relaunch.
5. **Fetch / parse** — Toolbar **Refresh** fetches each HTTPS feed (RSS 2.0 or Atom), upserts items (new → unread), and shows a clear error alert on network/parse failure.
6. **Read machine** — Selecting an item marks it read; Mark Read / Mark Unread toggles persist `is_read` across refresh and relaunch.
7. **Unread-first list** — Three-column hierarchy: sidebar feeds → unread-first item list → detail. Unread rows appear above read rows.
8. **Detail view** — Detail pane shows title, link, date, and body as plain text or simple HTML (AttributedString / sandboxed WKWebView, JS off).
9. **Mark feed read** — Toolbar / menu / context **Mark Feed Read** marks all items in the selected feed.
10. **Mark all read** — Toolbar / menu **Mark All Read** marks every item globally.
11. **Manual + timed refresh** — Toolbar Refresh (⌘R) always works; Settings → Automatic refresh interval drives an optional timer that reuses the same refresh pipeline (`FeedFetcher.refreshAll`).

Later sorts (sidebar unread badges, denser UX polish, packaging) remain out of scope for this commit.
