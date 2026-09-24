# Bridge Protocol: halide-permission-bridge (+ prop/notification/share summarized)
**Parent: ch.05 §9 · Owner: Platform/Privacy · Version: v1 · Rule: one prompt, two stores, atomic**

## 1. Permission mapping table (normative source: `bridges/permission-map.csv`)

| User-facing | Host store (xdg-permission-store/PolicyKit) | Android grant (`pm grant/revoke`) | Notes |
|---|---|---|---|
| Location | `org.freedesktop.portal.Location` allow | `ACCESS_FINE_LOCATION` (+COARSE implied) | background-location is separate toggle (two rows, never bundled) |
| Microphone | `org.freedesktop.portal.Device` mic / PipeWire node perm | `RECORD_AUDIO` | active-use indicator both sides (host LED-dot + Android green-dot must agree) |
| Camera | portal camera + device node ACL | `CAMERA` | indicator agreement tested like mic |
| Contacts | EDS collection ACL | `READ_CONTACTS` (+WRITE separate row) | read≠write (two prompts if app wants both) |
| SMS | Chats provider role | `READ_SMS`/`SEND_SMS`/`RECEIVE_SMS` (three rows) | SEND requires extra confirm on first use (billing risk) |
| Storage/Media | xdg-documents portal + per-dir FD | `READ_MEDIA_IMAGES/VIDEO/AUDIO` (scoped, no broad storage v1) | no `MANAGE_EXTERNAL_STORAGE` mirror v1 (documented gap) |
| Phone/Calls | Calls dial-out role | `CALL_PHONE`/`READ_CALL_LOG` | host dialer pin unaffected (ch.05 §11) |
| Notifications | notification-portal allow | `POST_NOTIFICATIONS` (+ listener allowlist separate) | listener = system `HalideListener` only (ch.05 §9) |

No silent inheritance (ch.08 §6): granting Android READ_SMS never grants host contacts without its own prompt — the two-phase commit (§2) enforces per-store user consent records.

## 2. Atomic grant/revoke (two-phase commit)

`GRANT {perm_id, package, requested_scope}` → stage host grant (uncommitted) + stage Android grant (`pm grant` dry-run via permission-check API) → if both stage-OK, present ONE system prompt (package, perm, scope, both-stores note) → user allow → commit both, journal `PERM_GRANT {pkg, perm, both:true}`; user deny → rollback both (verify rollback: staged host grant absent + `pm check` denied). Either-side commit failure → rollback other side + `PERM_SPLITBRAIN` alert metric (must be 0 in release — split-brain is P0). Revoke mirrors with ≤10s propagation (timer test `tests/permission-sync.sh` ×20, 0 desync).

First-use SEND_SMS/billing-adjacent perms: double-confirm (prompt + explicit "may cost money" line with carrier note). Background-location: upgrade prompt only after foreground granted ≥24h (no Day-0 background grab).

## 3. prop-bridge contract (summary; full table in `bridges/prop-allowlist.txt`)

Read set: `sys.boot_completed`, `gsm.*`, `cdma.*`, `battery.*`, `persist.sys.timezone/locale` (verify), `ro.build.fingerprint` (display only). Write allowlist (v1, exact): `persist.sys.timezone`, `persist.sys.locale` — host wins conflicts (§4: host clock/locale authoritative; Android `auto-time` slaved). Poll 2s + event push; change-in-Settings→reflected ≤5s both directions (timer test). Everything else: `DENIED` + audit line.

## 4. notification-bridge contract (summary)

`HalideListener` (system-signed, no INTERNET) → D-Bus `org.freedesktop.Notifications` (title/body/icon/package/ts). Actions v1: open-only. Rate-limit 20/min/package (excess → `RATE_LIMITED` + digest "3 more from X"). DND mirrors host; icons cached (`~/.cache/halide/notif-icons/`, 50MB cap, LRU). Test: 50 mixed notifications, order+badge match; spam-burst 100 from one package → capped + digest shown.

## 5. share/clipboard contract (summary)

Android→host guaranteed (text/URI/images via `/run/halide/share/` FD pass with 10MB cap + MIME allowlist; richer formats → documented-degraded with format table in Settings). Host→Android: text/URI guaranteed via bridge broadcast; binary reverse Phase-4 (labeled gap). Clipboard auto-clear 60s for password-flagged content (both directions).

## 6. Fuzz + audit

All four parsers under libFuzzer (`fuzz_perm/prop/notif/share_*`); SOCKETS.md rows for each socket (ch.05 §10 — audit script covers these too). `PERM_SPLITBRAIN` + indicator-disagreement metrics dashboarded in dogfood (ch.10 §10 daily form includes "permission prompt weirdness?" line).

## Verification

- [ ] `permission-sync.sh` ×20 green; split-brain counter 0 over dogfood.
- [ ] Indicator agreement (mic/camera/location dots) sampled 50 toggles, 0 mismatch.
- [ ] Spam-burst + oversize + unknown-perm rejection proven in contract tests.
