# cache-rotations.md — rotation log (ch.09 §18: date, trigger, old/new key prefixes, GC'd bytes, canary).
# Reviewed in the quarterly infra review alongside the runner game-day.

## Schedule

| Trigger | Cadence | Effect |
|---|---|---|
| manifest | automatic — new MANIFEST.lock SHA = new key namespace | old namespace read-only 14 days (bisect builds), then GC |
| time | ccache namespace every 90 days (quarterly); container layers on every builder-image rebuild | digest-pinned image, never floating tag |
| emergency | any compromise signal or canary divergence | rotate all keys immediately, purge shared bucket writes 24h, builds run cold |

## Rotation log (append-only)

| Date | Trigger | Old key prefix | New key prefix | GC'd bytes | Canary result |
|---|---|---|---|---|---|
| 2026-01-15 | initial (bookworm-20260101 snapshot, digest-pinned builder image) | n/a | manifest-00000000-dockerfile-20260210-clang17 | 0 | n/a |
| TODO-next | quarterly 90-day ccache | manifest-00000000-* | manifest-XXXXXXXX-* | TODO | cache-bypass canary PASS |
