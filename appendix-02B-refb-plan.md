# Appendix 02-B — REF-B (MediaTek/Tensor-class) Bring-Up Plan & Risk Containment
**Parent: ch.02 · Status: starts 6 weeks after REF-A Phase-1 green · Rule: timeboxed, never allowed to block REF-A**

## 1. Why REF-B hurts more (say it upfront so the schedule survives contact)

Mali GPU (Panfrost/Valhall maturity lags Freedreno on the specific IP in most candidate SKUs — ch.06 §2 passthrough debt likely), modem integrated differently (MTK `ccmni` vs QMI/QRTR path — the entire ch.07 ladder re-validated, not reused), vendor DT far from mainline (expect 2–4 weeks of `pinctrl`/regulator archaeology before UART+DRM), ISP closed harder (camera adapter from ch.04 §9 may cover only preview v1 — stills-via-libcamera gap recorded per sensor, no parity claims).

## 2. Timebox & exit ramps (binding)

6-week lag start, 8-week prove-out: weeks 1–2 UART+DRM+UFS (else re-scope SoC choice — sunk-cost rule written here so it can be cited later), weeks 3–4 modem-host (`ccmni` or equivalent enumerated + `mmcli -L` shows modem), weeks 5–6 container boot_completed headless, weeks 7–8 Phosh + 1 app. Miss any gate by >2 weeks → Arch review with three options (extend once with named owner, demote to community-port, drop) — decided in the review, not drifted.

## 3. Delta checklist vs REF-A (only what differs — no duplicated content)

GPU: Mali IP version → Mesa driver (`panfrost`/`v3d`-class) version pin + `glmark2-es2-drm` baseline vs REF-A number (record ratio, not vibes) → blob-vs-upstream decision with `UPSTREAMING.md` entry (ch.03 §20 ledger covers this too). Modem: control path (`ccmni`/`wwan`/`mbim`?) → MM plugin name pinned (ch.07 §9 plugin-flap rule applies double here) → APN/Carrier matrix subset (2 carriers, not full blessed list). Power: PMIC/gauge different → full ch.10 §8 calibration redo (REF-A numbers never reused — different silicon, different lies). AVB: own `flashmap.json` + appendix-08A-style policy file (`appendix-08B`) — partition sizes differ, never copy REF-A sizes.

## 4. Shared-with-REF-A (explicit, so work isn't redone)

Bridge protocols (all of `bridges/` — transport-identical), sepolicy shapes (new device contexts only), OTA/CI/release machinery (new SKU lane, same gates), dogfood protocol (separate fleet of 5, same forms), compat matrix (same TOP-100 list, separate grades column per SKU).

## Verification

- [ ] Go/no-go recorded at each 2-week gate; deltas (GPU/modem/power/AVB) have own baselines, nothing inherited silently.
