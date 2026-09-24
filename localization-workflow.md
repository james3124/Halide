# Localization Workflow
**Parent: 01-vision-requirements-personas.md (NFR top-12 locales) / 05-debian-systemd-dual-init.md**

## 1. Scope and locale contract
Top-12 shell locales for Phosh/host; Android locale follows system locale via prop-bridge allowlist (`persist.sys.locale` ≤5 s sync). v1 ships locales only when host + bridge strings both land — a locale with half a UI is flagged `partial` in Settings, never silently half-translated. systemd-as-PID1 note: `halide-prop-bridge.service` owns locale propagation; container never sources locale independently.
Privacy: translation bundles contain no IMSI/IMEI/logs; screenshot fixtures use synthetic contacts (`Ada Example`, `+1555…`).

## 2. String extraction for both stacks
Host: `xgettext` over `overlays/halide` (bridges, composer, drawer daemon, Settings panels) + `intltool` for `.desktop` shims; output `po/halide-<lang>.po` with `POT-Creation-Date` pinned to MANIFEST date for repro. Android: `aapt2`-adjacent `android-strings-extract` over container overlays (`vendor/halide/overlay`) collecting `strings.xml` → `l10n/android-<lang>/strings.xml`. CI job `l10n-extract` fails on: duplicate msgids with divergent meanings (must add context), unmarked format strings (`%s` without positional `%1$s` where translators reorder), hardcoded English in new UI (grep `_[a-z ]` heuristics + review).
Extraction runs per MR touching UI; POT diff posted as bot comment.

## 3. Translator handoff
Push English source + screenshots-per-string to translation platform (Weblate recommended, self-hosted) weekly during dev, frozen at string-freeze (T-14 d). Handoff pack per locale: PO/XML files, glossary (`l10n/GLOSSARY.md`: HALIDE, Phosh, drawer, slot, wipe — never transliterate product verbs inconsistently), char-limit table (lockscreen ≤24, banners ≤90, drawer labels ≤30), and 5 reference screenshots. Translators never get device logs or real user data. Review: 1 native speaker + 1 engineer per locale approve; disputes resolved toward the shorter string (mobile truncation is the enemy).

## 4. Integration and testing
Import via `l10n-import <lang>` (validates XML/PO syntax, `msgfmt --check`, Android `aapt2 compile` dry-run). Device checks per locale: (a) timezone/locale flip in Settings propagates to `getprop persist.sys.timezone`/`persist.sys.locale` ≤5 s; (b) RTL smoke (§5); (c) permission prompt shows mapped dual-stack text (atomicity visible in both languages); (d) OTA changelog renders without tofu (font coverage check `fc-list :lang=<code>`).
Single-stack networking strings (VPN/hostspot) verified against actual NM states — no translation may rename two distinct states to one word (e.g. `connected` vs `connecting` must differ).

## 5. RTL smoke
Locales ar/he (or any RTL in top-12): boot → lock → home → drawer → Calls → Chats → Settings → one Android app. Assert: drawer icon order mirrors, badges stay anchored, phone-number/OTP digits stay LTR-isolated (bidi marks), back-gesture direction unchanged (documented, not mirrored v1), no clipped Approve/Send/Wipe buttons. Screenshot pair LTR/RTL archived per release. Failures get `rtl` label + screenshot diff.

## 6. Metrics and gates
Untranslated-count metric: `l10n-report` outputs per-locale `untranslated / fuzzy / total` for host + Android separately; release gate: top-12 each ≥98% host and ≥95% Android-bridge strings, 0 untranslated in lockscreen/calls/emergency/wipe flows (critical-string list `l10n/CRITICAL.txt` — any miss blocks). Trend dashboarded nightly; drop >1% week-over-week pages i18n owner. AVB/LUKS2/OTA security prompts are critical strings in all locales.

## Verification
- [ ] Extraction CI green; no hardcoded English in new UI; POT diff posted per MR.
- [ ] Per-locale report meets 98%/95% gates with 0 critical-string misses.
- [ ] Locale flip propagates host→container ≤5 s both directions tested.
- [ ] RTL smoke screenshots archived; bidi digits and anchored badges confirmed.
- [ ] Handoff pack contains glossary + limits + screenshots; no user data shared.
