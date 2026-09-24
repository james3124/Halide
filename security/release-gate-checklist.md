# release-gate-checklist.md -- hardening checklist, release gate (ch.08 S7)
# Owner: Security + Release * Every box green or the train halts. Checked by
# release-gate-check.sh (text-level in tree; device rows on lab units via adb).

- [ ] getenforce -> Enforcing (container + host SELinux where applicable); no
      permissive domain on user; halide-debug absent on user (S31 gate 4)
- [ ] aa-status -> halide-android, halide-bridges, halide-composer loaded+enforcing
      (complain-mode stragglers block)
- [ ] avbtool info_image -> flag 2, correct per-SKU key, rollback monotonic
      (avb-verify.sh; testkey on release = P0)
- [ ] cryptsetup luksDump -> Argon2id, cipher aes-xts-plain64 512-bit, slot count
      = 1 + escrow-only-where-demanded; brute-rate-limit tested (10 wrong -> delay)
- [ ] kdf-registry-check.sh green; unlock p50/p95 within SLO (unlock-<sku>.md)
- [ ] seccomp filters on bridges (seccomp/*.json match); fuzz smoke green
- [ ] nft list ruleset matches security/nftables.conf baseline; per-app UID-mark
      counters move on toggle; VPN kill-switch fail-closed (tests/vpn-leak.sh)
- [ ] patch level <= 60 days; kernel CVE scan + AOSP bulletin delta + debsecan
      attached with disposition per CVE (PATCH-STATUS.md)
- [ ] signing ceremony log + transparency entry published; leak-scan.sh green
      (no private-key material in git)
- [ ] crypto-erase canary test passes on sacrificial unit (wipe-verify-procedure.md)
- [ ] USB defaults charge-only; ro.adb.secure enforced (CI greps ro.adb.secure=0)
- [ ] lockscreen 12-wrong-PIN script passes (delays + reboot persistence +
      emergency reachable); dmesg leak drill green (leak-check.sh)
- [ ] wipe-verify drill current quarter filed; research builds on research key +
      watermark + expiry (no release-key overlap)
- [ ] supply-chain review dates current (supply-chain-checklist.md); penetration
      scope frozen where applicable (pentest-worksheet.md)
- [ ] ro.hardware.keystore truthful (software/tee only, never strongbox v1);
      hb_strongbox_ prefix refused (keymaster-gatekeeper.md)
- [ ] VB failure screens exact copy + codes (VB-R1/R2); QR digest/rollback/slot
      only (vb-state-check.sh)
- [ ] wipe lot manifest passes wipe-stats.py arithmetic (where factory lots exist)
- [ ] credit wall updated atomically with advisories (links live, preferences honored)
- [ ] control-review evidence packs complete per family (review-evidence/<year>/)
