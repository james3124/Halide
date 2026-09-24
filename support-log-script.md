# Support Script — Phone Log Reading (`support/LOG-SCRIPT.md` + `halide-log-collect`)
**Parent: runbook-recovery §3, ch.10 §10 · Audience: non-engineer supporter + distressed user**

## 1. `halide-log-collect` contract (what it grabs, what it redacts, where it goes)

Grabs: versions (`/etc/halide-release` + container `build.prop` halide lines), `dmesg` tail, `journalctl -b` errors slice, `logcat -b all -d` crash slice (tombstones + FATAL), `avbtool info` state, slot state (`bootctl`), last OTA report, power top snapshot. Never grabs: userdata files, photos, SMS bodies, keystrokes, full `logcat` main (too leaky). Redaction (`--redact`, default-on, `--no-redact` requires typed reason + eng build): IMSI/IMEI/ICCID/phone-number regexes + QMI TLV denylist (ch.07 §7) + MAC randomization-aware Wi-Fi BSSID masking (BSSIDs locate people — masked to OUI). Output: `halide-logs-<sku>-<ver>-<ts>.tar.gz` + printed SHA256 (user reads over phone) + size (support knows if upload truncated).

## 2. Phone script (supporter reads, user taps — tested wording, no jargon)

1. "Open Settings → About → Export logs. Tell me the code on screen." (SHA prefix — confirms same bundle.)
2. "Is there a red line saying UNTESTED next to Emergency?" (routes to ch.07 §10 status — sets expectations before debugging telephony.)
3. "Did the phone restart itself, or did an app close?" (P0 vs P1 triage, ch.10 §10 taxonomy in plain words.)
4. "Plug into Wi-Fi, tap Upload with diagnostics ON/OFF as you prefer — either is fine." (consent restated, ch.05 §12 backup-report honesty.)
5. Read-back close: "Your version X on unit-class Y — the fix for your class ships in Z or we swap the step." (No "soon".)

## 3. Triage SLA & labels (support→engineering handoff)

`NEEDS-INFO` (support asks once, template), `DUPE` (linked canonical), `NEW-BUG` (QA reproduces in 48h or asks lab). Crash bundles auto-file draft issues with HALIDE-Ax label + redacted bundle attached (no human paste step — paste steps lose logs). Weekly support→QA sync (20 min): top-3 user pains vs bug-review top-3 — mismatch investigated (telemetry-off users are invisible in dashboards; the sync corrects for that).

## Verification

- [ ] Non-engineer completes script with a tester playing confused-user; redaction spot-check (planted fake IMEI found redacted, real one never committed).
