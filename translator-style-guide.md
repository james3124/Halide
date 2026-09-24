# Translator Style Guide — HALIDE Dual-Stack Voice
**Parent: localization-workflow.md / 01-vision-requirements-personas.md (top-12 locales)**

## 1. Voice and tone contract
HALIDE speaks as one system across two stacks: host (GNOME/Phosh idiom) and Android container (AOSP idiom). Tone is plain, direct, reversible: every destructive or connectivity action states consequence and undo path. Write at Grade-8 reading level in English source; translators preserve grade, never elevate formality to compensate. Imperative for buttons (`Wipe`, `Approve`, `Disconnect`), present-continuous for transient states (`Connecting…`, `Syncing locale…`), past participle only for completed results (`Connected`, `Wiped`). No exclamation marks in system UI. No first-person mascot voice (`Oops!`, `We couldn't…`); use neutral second-person or impersonal: `Couldn't connect to VPN. Retry?` Emergency, lockscreen, calls, wipe strings use short-sentence form (≤12 words) and are listed in `l10n/CRITICAL.txt` — these never ship fuzzy.
Procedure: author drafts English → i18n owner checks grade + button/state grammar → screenshot fixture attached before Weblate push → freeze at T-14 d per localization-workflow §3.

## 2. Top-12 locale terminology table
Base list follows NFR top-12 (confirm against 01-vision each release — this guide never redefines the set). Each locale keeps `l10n/terms-<lang>.md` for the 12 controlled terms below; transliteration of product nouns is forbidden unless allowed.

| # | English term | Host (GNOME) preference | Android bridge preference | Notes per locale family |
|---|---|---|---|---|
| 1 | Drawer | App grid equivalent | Drawer | de `App-Übersicht`; zh-CN 抽屉 launcher only |
| 2 | Slot (SIM) | SIM slot 1/2 | SIM 1/2 | es/pt keep consistent; hi only if carrier term matches |
| 3 | Wipe | Erase all data | Erase | Never `delete`/`remove`; tr `sil`, pl `wymaż` |
| 4 | Approve / Deny | Allow / Deny | Allow / Deny | Pair stays parallel; fr `Autoriser/Refuser` |
| 5 | Connected / Connecting | Verbunden-pattern | Same pair | Must never collapse to one word (see §3) |
| 6 | Hotspot | Hotspot | Hotspot | Host owns radio; container must not imply AP ownership |
| 7 | Update | System update | System update | OTA = `System update`; Debian packages = `Update` |
| 8 | Emergency call | Notruf-pattern | Emergency call | Never abbreviate; always critical string |
| 9 | Language | Sprache-pattern | Language | `Locale` never user-visible |
| 10 | Work profile | — (host has no twin) | Work profile | Container-only; host leaves `—` |
| 11 | HALIDE (brand) | HALIDE (untranslated) | HALIDE | Never transliterate; ar/he LTR-isolate |
| 12 | Phosh | Untranslated | — | Component names stay English |

Dispute rule (§3 workflow): shorter string wins on truncation risk. Log decision in `terms-<lang>.md`.

## 3. Dual-stack string pitfalls (Android vs GNOME conventions)
Check every new string against this table before Weblate push.

| Pitfall | GNOME/host | Android | HALIDE rule |
|---|---|---|---|
| Ellipsis | `…` on dialog buttons (`Wipe…`) | No ellipsis on final actions | Host keeps it; bridge strips only where AOSP expects `Wipe` |
| Capitalization | Sentence case buttons | Sentence case | Source sentence case; German nouns excepted |
| Plurals | `ngettext` + `Plural-Forms` | `plurals one/other` (+ `few/many` ar/pl) | Missing `few` for pl/ar blocks import |
| Format reordering | Positional `%1$s` if ≥2 args | Same + `%1$d` | Unmarked `%s` fails extract; reorder via positionals only |
| Time/date/number | GLib + ICU host | `getBestDateTimePattern` | Never hardcode `MM/DD`; test de 24h + ar-EG digits; OTP LTR-isolated |
| Permission verbs | `Allow once / While using / Deny` | Same triple | Both stacks show same decision; verify per workflow §4(c) |
| Host-only states | NM `connected/connecting` | No twin | Container shows host-propagated state verbatim |

Procedure per UI MR: run `l10n-extract`, post POT diff, attach host + container shots, tag i18n owner.

## 4. Forbidden literal translations — list pattern
Maintain per-locale `l10n/forbidden-<lang>.txt` as regex + replacement + rationale. Pattern format (one rule per line, `#` comment required):

```
# EN pattern | forbidden target | required target | rationale
Wipe\b | löschen (bare) | Alle Daten löschen | bare löschen understates factory erase
Slot\b | Steckplatz (SIM context) | SIM-Steckplatz | disambiguate from expansion slot
Drawer\b | Schublade | App-Übersicht | Schublade is furniture, not launcher
Connected\b = Connecting\b collapse | * | * | two NM states must differ (import blocker)
HALIDE | (any transliteration) | HALIDE | brand invariant
```

Rules: (a) each entry cites a real bug ID or review comment — no speculative entries; (b) `l10n-import` greps translations against forbidden lists and fails with file:line + rule ID; (c) emergency/wipe forbiddens are release blockers, others are warnings promoted to blockers at string-freeze; (d) never add a rule that forces a string over char limits (lockscreen ≤24, banners ≤90, drawer ≤30) — fix source instead. Review forbidden lists quarterly; remove rules with zero hits over two releases.

## 5. Screenshot-context requirements for translators
No string ships without visual context. Per changed string: (1) host shot 360×720 @2x + container shot where bridged, string boxed red in fixture only; (2) `context:` line with screen path, max chars, truncate/wrap; (3) state pair for dynamic strings; (4) RTL mirror for ar/he if layout-adjacent; (5) synthetic data only (`Ada Example`, `+1555…`). Naming: `l10n/shots/<screen>-<lang>-<build>.png`, retain one release. Strings without shots are `needs-context` and excluded from the 98%/95% gate numerator.

## 6. QA linguistic review sampling
Two gates per locale: native speaker + engineer. Sample per release: 100% of `CRITICAL.txt` + random 10% host + 10% bridge (min 40/stack/locale), plus all changed strings and prior-truncation strings. Verdicts (`accept/fix/source-fix`) in Weblate; `fix` lands pre-RC. Metric: defects per 1k words; >5 major/1k blocks locale to `partial`, never silently half-shipped. Release notes list per-locale percentages verbatim.

## Verification
- [ ] `terms-<lang>.md` covers 12 terms; brand invariant holds.
- [ ] `l10n-extract` green; no unmarked `%s`; POT diff posted; pitfall table checked.
- [ ] Forbidden lists enforced by `l10n-import`; every rule cites bug/review; no rule forces over-limit strings.
- [ ] Every Weblate string has screenshot + context line with synthetic data only; `needs-context` excluded from gate.
- [ ] Sampling (100% critical + 10%/40-min per stack) recorded; defect rate ≤5 major/1k; partial locales flagged, never silent.
