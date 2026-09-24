# HALIDE Docs Style Guide — Plan + User Docs Voice

**Parent: 00-index-and-how-to-read.md Conventions · Owner: Arch + Docs · Phase: all**

## 1. Voice and tone (two registers, no mixing)

Plan register (this plan, runbooks, specs): imperative, verifiable, pessimistic. Every instruction states actor, command, and stop condition. No adjectives without thresholds. User-docs register (Phosh help, fleet admin guide, support scripts): second-person, task-first, reassuring but never promising. Both registers obey honesty rules: no verbal gates, no "should work", no forward references without file+section.

| Register | Do | Do not | Example |
|----------|----|--------|---------|
| Plan | command + Expected output + log-on-mismatch | "simply", "just", "obviously" | `lxc-attach -n android -- getprop sys.boot_completed` → `Expected: 1` |
| User | goal → steps → verify → undo | internal codenames, gate numbers | "To check for updates: Settings → System → Updates → Check. You see a date." |
| Both | cite version+SKU fingerprint on every claim | claim GMS / Widevine L1 / Play Integrity (explicit v1 non-goals) | "Verified on halide-seabird build 2026-08-14, REF-A 4GB SKU" |

Tone test: if a tired on-call engineer at 03:00 or a non-technical owner can misread it, rewrite it. Active voice always. Maximum one conditional per step; second conditional becomes a new step.

## 2. Terminology registry (allowlist/blocklist)

Canonical terms are greppable. `scripts/plan-consistency.sh` enforces them; drift fails CI.

| Allowlist (use) | Blocklist (never) | Why + example |
|-----------------|-------------------|---------------|
| Android container, Debian host | Android VM, emulator, nested Android | Native LXC, not emulation. Ex: "restart the Android container" |
| bridge (named: prop→D-Bus, RIL→MM, HWC→Wayland) | shim, glue, middleware layer | Bridges have proto_v + safe-mode; generic words hide that |
| staged rollout (1%→10%→50%→100%) | push update, release to everyone | Rollouts halt on regression (ch.09 §9) |
| permission sync (atomic) | permission mirror, permission copy | Android + Linux grant must commit atomically or roll back both |
| NetworkManager (single-stack owner) | Android netd routing, dual-network | Single-stack: NM owns routing, Android netd is bridged client |
| blob SHA + manifest range | driver version (bare) | Reproducibility needs SHA + MANIFEST range |
| P0/P1/P2 (plan §11 rubric) | critical-ish, urgent, ASAP | One severity language across support/QA/engineering |

New terms require Arch approval + entry here + grep alias added to consistency script same MR. No synonyms in the same file.

## 3. Procedure-writing template (command → Expected → gotcha → fix)

Every procedure uses this four-column block. No procedure without Expected. If output differs, stop — do not proceed.

```bash
halide-doctor --check bridges --sku REF-A-4GB
# Expected: all bridges proto_v match, permission-sync atomic OK
# Gotcha: stale LXC socket after unclean shutdown shows proto_v mismatch
# Fix: sudo systemctl restart halide-bridges && halide-doctor --check bridges
```

Template table for authors:

| Field | Required content | Anti-pattern |
|-------|------------------|--------------|
| Command | full path/flags, host vs container prefix, SKU | bare `make` with no target |
| Expected | literal output block, exit code, threshold | "looks good", "no errors" |
| Gotcha | one known false-pass/false-fail + log to pull (`dmesg`/`logcat`/`journalctl`) | silent edge cases |
| Fix | single recovery command + re-verify command | "reboot and retry" without verification |

Long procedures (>10 steps) add a failure table at the end: symptom → log → fix. Redaction rule: any pasted log must pass `support-log-script --redact` (strips IMEI/IMSI/ICCID, MAC, GPS, key material) before commit. Never paste raw `logcat -b radio` or `journalctl` with identifiers.

## 4. Screenshot and photo standards

Screenshots prove UI state; photos prove hardware state. Both need provenance or they are decoration.

1. Capture: Phosh screenshots via `gnome-screenshot -w` on-device, never composited mockups. Lab photos: fixed tripod, neutral background, ruler or caliper in frame for scale where size matters.
2. Annotate: red 2px box + numbered callout, caption below with build fingerprint + date. No free-floating arrows.
3. Store: `docs/assets/<file>-<slug>-<YYYYMMDD>.png` (max 800KB, PNG, 2x for text legibility). No external image hosts.
4. Redact: blur status-bar IMEI, notification PII, QR pairing codes, serial labels. Verify blur survives 200% zoom before commit.
5. No fake claims: never show GMS Play Store, Widevine L1 badge, or signal bars implying certification not yet earned. Carrier-lab photos label uncertified state explicitly.

Each image MR includes alt-text (one sentence, functional) for accessibility-test-plan compliance.

## 5. Doc-bug SLA handling

Confusion reports are doc bugs with quoting-line. Channel: every chapter ends with Next-link; reader files issue quoting exact line. Triage as docs-P1/P2 reusing P0/P1/P2 clocks at docs scale.

| Class | Example | Clock | Owner |
|-------|---------|-------|-------|
| docs-P1 (blocks onboarding/gate) | procedure Expected mismatch on REF-A | acknowledge 48h, fix ≤14 days (doc-bug SLA 2 weeks) | chapter Owner |
| docs-P2 (typo, clarity, broken link) | wrong socket path in one example | fix ≤30 days or next release train | Docs |
| docs-P0 (safety/compliance risk) | wrong fastboot unlock step risking brick | halt referencing rollout, hotfix ≤7 days | Arch + Security |

Stale-procedure check: owners re-run their commands per release; rotten runbooks fixed same cycle. Quarterly cross-chapter sweep verifies prop names, socket paths, metric names identical everywhere. Annual retrospective reports kept-vs-rewritten ratio.

## Verification

- [ ] New/edited chapter passes `scripts/plan-consistency.sh` with zero term drift.
- [ ] Every procedure has Command→Expected→gotcha→fix; every pasted log is redacted.
- [ ] Images have provenance caption, alt-text, ≤800KB, blur verified at 200%.
- [ ] No GMS/Widevine/Integrity claims; no blocklisted synonyms.
- [ ] Open doc bugs within SLA; onboarding doc-filed-per-onboarding metric recorded.
