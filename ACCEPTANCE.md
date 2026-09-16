# LocusFeed acceptance (MVP sorts 1–4)

Unsigned local Debug on macOS 15+ with Xcode.

1. **Naming** — App displays as LocusFeed; bundle `studio.locusable.LocusFeed`.
2. **Skeleton** — `make generate && make build` produces a runnable window app (Menu + WindowGroup).
3. **Store** — SQLite file under Application Support stores `feeds` and `items` tables; models compile via LocusFeedCore.
4. **Feed CRUD** — UI can add / edit / delete subscription feeds; rows persist across relaunch.

Later sorts (fetch/parse, unread machine, mark-all-read, etc.) are intentionally out of scope for this commit.
