# EOL & Data Export Runbook — No Stranded Encrypted Bricks
**Parent: ch.01 §13 support policy, ch.05 §12 backup · Trigger: EOL-90-day notice · Owner: Program/Release**

## 1. EOL notice contents (published, not whispered)

Final-signed image version + its support-end date, export-tool version, per-app data portability table (contacts/SMS/photos/call-log = guaranteed formats vCard/XML/CSV+files; app-internal Android data = per-app-agent documented, gaps named), unlock/relock guidance for tinkerers post-EOL (keys + `fastboot flashing unlock` consequences incl. wipe warning), and the explicit sentence: "After <date>, no security updates. Do not use as a daily phone." (ch.01 §12 honesty rule extends to end-of-life — abandoned users told plainly.)

## 2. Export procedure (tested BEFORE the notice goes out — order matters)

`halide-export` (Settings → System → Export my data): full `halide-backup` (ch.05 §12) + decryption of FBE app keys with PIN (one-time, in-memory only) + portable archive (`halide-export-<date>.tar` + `MANIFEST.json` with hashes + reader script `halide-import --list` that runs on any Debian 12+ without our images). Verification drill: export from EOL-candidate build → import-list on stock Debian laptop → contacts/SMS/photos verified by second person (two-person rule like audio tuning — your own export always "works"). Failure blocks the EOL notice (can't announce EOL with broken exit).

## 3. Post-EOL device states (user chooses, all supported by tooling)

Stay-on-final (with the plain warning above), reflash-to-stock (factory images linked + EDL/flashall steps per SKU — our docs don't orphan stock-returners), unlock-and-tinker (community keys path, ch.08-A §4 yellow state). Enterprise P3: fleet attestation final-report (wipe-or-remain per device with serials — auditors get closure, not silence).

## Verification

- [ ] Export→import-list drill passes with second-person verify before any EOL notice ships.
