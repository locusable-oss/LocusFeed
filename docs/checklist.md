# LocusFeed MVP checklist

Unsigned local acceptance for macOS 15+. **Do not tag** and do not cut a GitHub Release from this checklist. Packaging is a later work item.

- Linux (no Xcode): `make self-check` — static checks only.
- macOS with Xcode: `make generate && make build` (ad-hoc identity `-`), then walk the manual steps.

Anchors below (`<!-- check:… -->`) are read by `scripts/self-check.sh`.

## License

<!-- check:license -->

- [ ] Root `LICENSE` is GPL-3.0 and `COPYRIGHT` names Locusable Studio.

## Identity and unsigned build

<!-- check:file:project.yml -->
<!-- check:file:Makefile -->
<!-- check:contains:project.yml:studio.locusable.LocusFeed -->
<!-- check:contains:project.yml:CODE_SIGN_IDENTITY: "-" -->
<!-- check:contains:Makefile:CODE_SIGN_IDENTITY="-" -->

- [ ] App displays as LocusFeed. Bundle id `studio.locusable.LocusFeed`.
- [ ] Debug build is unsigned / ad-hoc (`CODE_SIGN_IDENTITY=-`). No Developer ID, no notarization.

## Store, fetch, read state (sorts 3–11)

<!-- check:symbol:FeedStore -->
<!-- check:symbol:FeedFetcher -->
<!-- check:symbol:setItemRead -->
<!-- check:symbol:markAllRead -->
<!-- check:symbol:refreshAll -->

- [ ] SQLite under Application Support stores feeds and items across relaunch.
- [ ] Add / edit / delete subscriptions persist.
- [ ] Toolbar **Refresh** (⌘R) fetches HTTPS RSS 2.0 or Atom, inserts new items as unread, and alerts on failure.
- [ ] Opening an item marks it read. Mark Read / Mark Unread survive refresh.
- [ ] Three columns: sidebar feeds, unread-first items, detail (plain text or simple HTML, JS off).
- [ ] **Mark Feed Read** and **Mark All Read** clear the matching rows.
- [ ] Settings → Automatic refresh drives the same fetch pipeline. Off leaves only manual refresh.

## Unread counts (sort 12)

<!-- check:symbol:unreadCountsByFeed -->
<!-- check:symbol:unreadByFeed -->

- [ ] Each sidebar feed shows a source-level unread badge. Zero unread hides the badge.
- [ ] The sidebar header total matches the sum of badges.
- [ ] Marking read, mark-all, and refresh update badges without restarting.

## Settings (sort 13)

<!-- check:symbol:LaunchBehavior -->
<!-- check:symbol:refreshOnLaunch -->
<!-- check:symbol:focusFirstUnread -->
<!-- check:symbol:BodyFontSize -->

- [ ] Settings → Automatic refresh offers Off, 15 min, 30 min, 1 hour, 2 hours, 6 hours.
- [ ] On launch is one of: Open only, Refresh all feeds, Jump to first unread. The choice applies on the next launch.
- [ ] Body size (Small / Regular / Large / Extra Large) changes plain text, attributed HTML, and the sandboxed web view. Titles stay at the title style.

## Unread stream (sort 14)

<!-- check:symbol:ListDensity -->
<!-- check:symbol:markReadAndAdvance -->
<!-- check:symbol:plainSnippet -->
<!-- check:symbol:cycleDensity -->

- [ ] Compact rows are one line plus a relative time. Comfortable rows add a one-line excerpt.
- [ ] **Unread Only** hides read rows. Empty unread state reads "All caught up".
- [ ] The row checkmark and ⌘U toggle read state. Badges move with the row.
- [ ] **Next Unread** / ⌘J marks the current item read and highlights the next unread item without marking that next item read.

## No tag

<!-- check:no-tag -->

- [ ] `make self-check` passes.
- [ ] No git tag and no GitHub Release is created by this acceptance.

## Manual walk (macOS only)

1. `make self-check && make generate && make build`.
2. Launch the unsigned app. Add an HTTPS feed and Refresh.
3. Confirm the sidebar badge equals that feed's unread count, and the header total equals all badges.
4. Open Settings (⌘,). Set body size to Extra Large and confirm the article body grows. Set On launch to "Jump to first unread".
5. Toggle Compact and Unread Only. Press ⌘J through the unread items; the highlighted row stays unread until it is opened or marked.
6. Mark Feed Read, then Mark All Read. Badges clear and survive relaunch.
