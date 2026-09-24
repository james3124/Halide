# HALIDE Bridge & API Stability Policy — Version, Freeze, Notify

**Parent: ch.04 manifests/HAL pins · ch.05 bridges · ch.09 OTA trains · Owner: Platform + Arch**

## 1. Bridge protocol versioning (proto_v discipline)

Each bridge (prop→D-Bus, RIL→ModemManager, HWC→Wayland, audio, sensors) carries `proto_v: MAJOR.MINOR` in its manifest and in `halide-doctor` output. MAJOR = breaking wire change; MINOR = additive field. Rules:

1. Bump MAJOR only on OTA major train with staged rollout; bump MINOR any train. Record bump in MANIFEST delta + OTA release notes with before/after `proto_v` table.
2. Support window: N and N-1 MAJOR supported for 2 release trains (deprecation window). N-2 refused. Example: prop-bridge v3 ships; v2 accepted with warning for 2 trains, then refused.
3. Mixed-version refusal is fail-closed and loud. Procedure:

```bash
halide-doctor --check bridges --verbose
# Expected: prop-bridge host v3.1 / container v3.1 MATCH; ril-bridge v2.4/v2.4 MATCH
# Gotcha: OTA interrupted mid-container leaves host v3 / container v2 → all cross-bridge calls refuse with PROTO_MISMATCH banner (by design)
# Fix: complete OTA or rollback both slots via update-engine; never force --allow-mismatch except lab debug with serial logged
```

Honesty rule: `--allow-mismatch` never ships in user builds; lab use requires `halide-log --tag proto-override` entry. Permission atomicity preserved across bumps: permission-sync transaction versioned with bridge proto; partial apply rolls back both Android and Linux sides.

## 2. D-Bus interface stability tiers

All host-side contracts are D-Bus; Android side stays AIDL/HIDL pinned per ch.04. Tiers:

| Tier | Examples | Stability promise | Change process |
|------|----------|-------------------|----------------|
| Tier-1 frozen | `org.halide.Power.Residency`, `org.halide.PermSync`, `org.halide.NetRoute` (single-stack NM owner) | frozen across v1; breaking change needs Arch + Security sign + major train | 90-day notice + migration shim + staged rollout 1% bake 24h |
| Tier-2 evolving | `org.halide.Camera.Ext`, `org.halide.Sensor.Fusion` | MINOR-additive freely; MAJOR once per year max | 30-day notice, N/N-1 support |
| Tier-3 experimental | `org.halide.Debug.*`, `org.halide.Lab.*` | no promise; may vanish any train | `Debug` prefix mandatory; blocked on user builds by build flag |

Procedure to query tier:

```bash
busctl --system introspect org.halide.Power /org/halide/Power | grep -i version
# Expected: Tier-1 .Residency proto_v 1.x, Annotated Stable-v1
# Gotcha: Tier-3 names appearing on user build = build-flag leak
# Fix: reject image in CI (sbom-license-template check includes tier audit)
```

Single-stack networking invariant: only `org.halide.NetRoute` (NM-owned) may program default routes. Android netd calls are proxied; direct `ip route` from container refused and logged.

## 3. HAL interface freeze exceptions

HALs pinned per ch.04 (AIDL camera, audio, GNSS). Freeze: no HAL MAJOR bump after Gate 2→3 without exception. Exception request fields: affected SKU range, MANIFEST range, why MINOR insufficient, rollback plan, power/thermal re-qual (ch.10 sheets), security review (SELinux+AppArmor delta). Approvers: Arch + BSP + QA. Emergency exception (modem FW forced by carrier): carrier-lab-handbook re-qual + staged rollout with radio-bake 1% 24h + auto-halt armed (ch.09 §9). All exceptions expire after one train unless renewed with data.

| Case | Allowed? | Conditions |
|------|----------|------------|
| Additive vendor prop, namespaced `vendor.halide.*` | yes, MINOR | sepolicy-deltas entry + redacted log sample |
| Breaking camera HAL for tuning gain | no, defer to v2 | use tuning-sheet overlay instead |
| Modem FW API shift (carrier mandate) | exception only | full modem-fw-qualification + emergency-call-cert re-run |

## 4. Developer notification lead times

One channel (developer-sdk-guide changelog), one calendar. No silent breaks.

| Change | Lead time | Content | Rollout |
|--------|-----------|---------|---------|
| Tier-1 MAJOR / bridge MAJOR | 90 days + 2-train overlap | migration guide, before/after traces, `halide-doctor` check | staged 1%→10%→50%→100%, halt on P0/P1 |
| Tier-2 MAJOR / HAL exception | 30 days | shim + deprecation warning string | monthly train |
| MINOR additive | 7 days (release notes) | field spec + sample | any train |
| Security-forced break | ASAP + T-24h fleet pre-notice (P3) | affected serials check, patch-vs-wipe | hotfix lane same-week |

Notification template: what changed / who is affected (fingerprint range) / what to run to verify (`halide-sdk-check --proto`) / what happens if ignored (refusal message text quoted). No fake claims: never promise backward compat beyond N-1; never imply GMS-dependent APIs exist.

## Verification

- [ ] `halide-doctor --check bridges` MATCH on both slots; mismatch refusal demoed on lab unit.
- [ ] D-Bus tier audit green; no Tier-3 on user builds; NetRoute single-owner proven (`ip route` from container refused).
- [ ] HAL freeze log current; any exception has approvers + re-qual sheets attached.
- [ ] SDK changelog lead times met; deprecation warnings greppable in code.
- [ ] Permission-sync atomicity test passes across proto bump (kill -9 mid-apply → both sides rolled back).
