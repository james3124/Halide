# HALIDE Field-Issue Escalation — Support → QA → Engineering

**Parent: ch.01 §11 support promise · incident-response-runbook · ch.09 staged rollouts · Owner: Support + QA + Release**

## 1. Support → QA → engineering ladder with clocks

Every field report gets an ID (`FLD-<Y>-<NNNN>`) at first contact. No report lives in chat; no verbal triage. Clocks start at first contact timestamp.

| Rung | Owner | Entry criteria | Actions + clock | Exit |
|------|-------|----------------|-----------------|------|
| L1 Support | Support | user message / fleet ticket | acknowledge 24h; run support-log-script (redacted), capture fingerprint+SKU+MANIFEST; attempt runbook-firstboot/recovery steps. `Expected: redacted bundle + repro-attempt log` | resolved or escalate ≤48h with bundle |
| L2 QA repro | QA | L1 bundle attached | reproduce on lab unit matching fingerprint (exact SKU — wrong-SKU repro invalid); file severity proposal; acknowledge 48h | repro yes/no + severity within 5 days |
| L3 Engineering | Platform/BSP owner | QA repro + severity | fix-or-mitigation per severity clock; MR refs FLD id; regression test committed | ship via train + advisory |
| L4 Post-resolution | Support + QA | shipped + staged rollout green | follow-up survey + close (see §5) | closed ≤14 days post-ship |

Procedure:

```bash
support-log-script --collect --redact --out /tmp/FLD-2026-0142.tgz
# Expected: bundle created, IMEI/IMSI/MAC/GPS stripped, manifest-range + proto_v included
# Gotcha: user on modified image (root/magisk) — log flags UNVERIFIED-BASE, route to best-effort queue
# Fix: halide-doctor --verify-base --sku REF-A-4GB; if UNVERIFIED, state support limits honestly (no fake promises)
```

Gotcha→fix: incomplete bundles bounce once with checklist; second bounce escalates to Support lead (process failure, not user failure). Redaction is mandatory before any upload.

## 2. Severity mapping to P0/P1/P2 (one language with security)

| Field severity | Maps to | Definition (HALIDE) | Fix clock |
|----------------|---------|---------------------|-----------|
| S0 fleet-down / safety | P0-CRIT | unsolicited reboots >5%/day fleet, emergency-call failure, verified-boot bypass, container escape, permission split-brain in wild | acknowledge 4h, mitigation ≤7 days, hotfix same-week, staged rollout halt armed |
| S1 broken daily-driver | P1-HIGH | calls/SMS/data/Wi-Fi/BT-audio/camera/GNSS broken on supported SKU, 24h standby missed >20%, OTA rollback failure | acknowledge 48h, fix ≤30 days (monthly train) |
| S2 degraded / workaround exists | P2-MED | single-app crash, minor thermal throttle, cosmetic Phosh glitch, single-stack VPN edge case with manual workaround | monthly train, 90-day cap |

Active-exploitation or safety flag auto-upgrades to S0/P0 (evidence required: telemetry, carrier anomaly, PoC-with-traffic). Single-stack networking failures (NM vs container route fight) default S1 minimum — connectivity is daily-driver. Permission-atomicity violations (Android granted / Linux denied split) default S1, upgraded S0 if in wild.

## 3. Fleet-incident war-room protocol

Triggered by: S0, or ≥3 S1 same fingerprint within 72h, or staged-rollout auto-halt (ch.09 §9). Commander: Release (button) + QA (repro) + Security if P0.

1. Open `fleet/WAR-<id>.md` (start-ts, fingerprint range, MANIFEST range, halt-status, commander). Freeze further rollout beyond current stage (1%/10%/50%) — no "one more stage to confirm".
2. Page within 1h (S0) / 4h (S1-cluster). Roles: commander, comms, repro, data (telemetry redacted), vendor-liaison if modem/blob suspect.
3. Cadence: 30-min updates S0, 4h S1-cluster. Each update: new data / decision / owner + time. No status without owner.
4. Contain options ranked: halt rollout → per-serial hold (`halide-fleet-check --war <id>`) → feature safe-mode (`halide-<x>-bridge --safe-mode`) → hotfix. Safe-modes tested quarterly, not invented live.
5. Close: root cause + MANIFEST delta blamed + regression test merged + retro ≤7 days. Skipped retros guarantee repeats.

## 4. User-communication templates per severity

Honesty + no fake claims in every message. Always state affected range, action, verify command.

S0 template: "HALIDE advisory [S0 FLD-…]: [issue] affects [build range + SKUs]. Action: [update/hold/reflash]. Verify: `halide-doctor --check …` → Expected […]. We halted rollout at [stage]. Next update [time]." S1: same minus halt line, plus workaround with undo steps. S2: release-notes entry + forum post. Never promise dates beyond train windows; never imply GMS/Widevine-dependent fixes; never ask users to disable verified boot or send unredacted logs. Fleet P3 channel gets T-24h pre-notice on S0 with per-serial affected check.

| Severity | Channel | First message | Cadence |
|----------|---------|---------------|---------|
| S0 | status page + P3 fleet + forum pin | ≤24h from war-room open | daily until mitigation |
| S1 | forum + release notes + fleet digest | ≤72h | per train |
| S2 | release notes | next train | — |

## 5. Post-resolution follow-up survey (close the loop, measure it)

Sent ≤7 days post-ship, closes ≤14 days. Three questions only: resolved? (verify command output requested), communication clear? (would-report-again?), effort score 1–5. Non-responses get one reminder; fleet admins get patched-count vs outstanding report (auditors close on this). Survey results feed quarterly support metric: doc-filed-per-onboarding + would-report-again rate. Low would-report-again triggers Docs + Support retro (silence breeds uncoordinated disclosure).

## Verification

- [ ] Every FLD has bundle (redacted) + fingerprint + severity + clock timestamps.
- [ ] Wrong-SKU repros zero; staged-halt honored at least once in drill.
- [ ] S0/S1 advisories use templates verbatim; no unredacted logs in tickets.
- [ ] War-room file + retro exist for each S0/cluster; regression test merged.
- [ ] Follow-up surveys sent ≤7d, closed ≤14d; metrics reported quarterly.
