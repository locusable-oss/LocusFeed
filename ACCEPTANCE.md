# LocusFeed acceptance

MVP sorts 1–15. Unsigned local Debug on macOS 15+ with Xcode. Linux runs static checks only.

Full checklist, including the machine anchors: [`docs/checklist.md`](docs/checklist.md).

```sh
make self-check
```

On a Mac, after the static check: `make generate && make build` (`CODE_SIGN_IDENTITY=-`). Walk the manual steps in `docs/checklist.md`.

This acceptance does **not** create a git tag or a GitHub Release.
