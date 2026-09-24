# wipe-verify-procedure.md -- wipe-verify ops (ch.08 S21, S28 sampling)
# Owner: Security + Release + QA * All trigger paths (user reset, recovery reset,
# enterprise remote-wipe, lockscreen wipe-at-N) converge on ONE implementation:
# halide-wipe --verify (divergent erase paths are how "wiped" devices keep photos).

## Procedure (ordered, logged to recovery log + attestation line)

1. Pre-wipe canary: write CANARY-<32-hex> to 3 userdata locations (file, sqlite
   row in Chats-layout scratch, raw offset note) + record LUKS header SHA.
2. Unmount userdata + kill container (no live writers during erase).
3. cryptsetup erase <data-keyslot> + blkdiscard -f userdata + new filesystem
   UUIDs + regenerate LUKS header (new salt -- old header image useless).
4. Post-wipe verify (BLOCKING, not advisory): header region differs from recorded
   SHA + must not decrypt with old wrapped key (attempt-and-fail logged);
   hexdump 3x 64MB windows searched for canary (absent = PASS); blkid shows new
   UUIDs. Any miss => WIPE-VERIFY-FAIL (refuses first-boot setup, "Erase
   incomplete -- retry" + support code; retry x3, then RMA-quarantine -- a
   half-wiped device must never look clean).
5. Attestation: WIPE <sku> <timestamp> <operator-confirm-id> <verify:PASS>
   <header-sha-new> in recovery log + QR-printable (enterprise MDM upload).

## Sampling (S28, factory/wipe-aql.md owns the table)

AQL 0.25% critical-defect; lot = one shift-one-station (<= 500 units);
rejected lot => 100% re-verify (read-only, not re-erase) + root-cause +
security/wipe-lot-<id>.md before restart. Rolling-200 halt on 2 fails.
Per-lot blind canary (QA injects into 1-in-20 unknown to operators).
Lot manifests validated by tests/wipe-stats.py (arithmetic must gate signing).

## Drill

Quarterly sacrificial-unit run (QA calendar): canary-absent + header-rotated +
attestation present => file from wipe-drill-TEMPLATE.md. Failed drill = P0.
