# LOG-SCRIPT.md — log collection runbook (support/LOG-HOWTO.md companion; ch.10 §10)
**Owner: Support + QA · Phase: 2+ — audience: non-engineer supporter + distressed user**

## What the script grabs (and never grabs)

Grabs: versions (`/etc/halide-release` + container `build.prop` halide lines), `dmesg` tail, `journalctl -b` error slice, `logcat -b all -d` crash slice (tombstones + FATAL), AVB state, slot state (`bootctl`), last OTA report, power-top snapshot.
Never grabs: userdata files, photos, SMS bodies, keystrokes, full `logcat` main (too leaky).

## Procedure (user taps, supporter reads)

1. Settings → About → **Export logs**. Ask for the code on screen (SHA prefix confirms same bundle).
2. Check for a red **UNTESTED** line next to Emergency (sets telephony expectations, ch.07 §10).
3. Ask: "Did the phone restart itself, or did an app close?" (P0 vs P1 triage, ch.10 §10 taxonomy).
4. "Plug into Wi-Fi, tap Upload with diagnostics ON/OFF as you prefer." (consent either way is fine.)
5. Close with read-back: version, unit class, fix path or swap step. No "soon".

## Redaction (default-on)

`--redact` strips IMEI/IMSI/ICCID/phone numbers + QMI TLV denylist + BSSID masked to OUI. `--no-redact` requires typed reason + eng build. Output: `halide-logs-<sku>-<ver>-<ts>.tar.gz` + printed SHA256 + size.

## Triage labels (support → engineering)

`NEEDS-INFO` (ask once, template) · `DUPE` (link canonical) · `NEW-BUG` (QA reproduces in 48h or asks lab). Crash bundles auto-file draft issues with redacted bundle attached — no human paste step.

Expected: bundle SHA256 matches the code the user read out; planted-IMEI redaction spot-check passes.

Fail action: truncated upload (size mismatch) → re-export; never post raw logs with IMEI to public trackers.
