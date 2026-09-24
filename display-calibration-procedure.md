# Display Calibration Procedure
**Parent: 06-graphics-wayland-phosh-bridge.md / graphics/<sku>/panel.json**

## 1. Scope and prerequisites
This procedure binds every panel variant to a measured `graphics/<sku>/panel.json`. Applies to REF-A (Adreno/msm) and REF-B (Mali) and any Phase-4 SKU. Host owns DRM master; Phosh/phoc is the display truth; Android `LightsService` follows host. No datasheet-copied curves ship as measured.
Lab kit: lux meter (e.g. Konica T-10 or equivalent, calibration date logged), colorimeter where available (X-Rite i1Display), dark room (<5 lux ambient), tripod jig at 30 cm normal incidence, REF unit with `simpledrm` fallback disabled for measurement, `grim` + `screencap` hosts tools, `halide-composer --debug`.
Entry gate: `modetest -M msm -s <conn>@<mode>` shows preferred mode from DT; `kmscube` runs 60 s without underrun.

## 2. Lux-meter backlight curve capture
1. Boot to Phosh, kill `gammastep`/night-light (`systemctl --user stop gammastep`), set composer debug overlay off.
2. Drive backlight through host class only: `for L in 0 1 13 64 128 192 255; do echo $L > /sys/class/backlight/*/brightness; sleep 5; <read lux>; done` — minimum 7 points (0 + 6), 5-point minimum per ch.06 §8.
3. At each point record: host level, Android `settings get system screen_brightness` (must mirror linearly per §5), lux (3 samples, median), `max_nits` estimate = lux × jig factor (jig factor measured once per lab rig with reference panel, stored in `graphics/lab-rig.json`).
4. Repeat after 10-min warmup; drift >5% restarts the run (cold-backlight lie).
5. Cheap-panel nonlinearity is expected — record it, never linearize by hand. Output array `backlight.curve` in nits ascending.

| Host level | Android mirror | Lux median | Nits | Notes |
|---|---|---|---|---|
| 0 | 0 | | | must be <2 nits or record light-bleed bug |
| 13 | 13 | | | low-end step most nonlinear |
| 128 | 128 | | | mid anchor |
| 255 | 255 | | | = `max_nits` |

## 3. White-point and gamma recording
1. Show full-field white via `halide-whitepatch white` (host) and compare container `screencap` white — single color pipeline: host owns DEGAMMA/CTM, Android Night Light disabled via overlay.
2. With colorimeter: record CCT (target 6500 K ±500), x/y chromaticity, mean per-channel Δ vs sRGB at 50% grey. Without colorimeter: record datasheet CCT with `measured:false` (renders amber in generated docs, per ch.06 §11).
3. Gamma: display 16-step greyscale PNG via `grim`-captured host path, read lux per step, fit gamma (expect ~2.2); store `gamma` + residual. Wide-color claims forbidden without measurement — v1 reports SDR sRGB only; HDR buffers rejected with `FORMAT_FUTURE` counter.
4. Night-light off during capture; one run with `gammastep` at 4500 K archived separately to prove single-manager application (no double-orange).

## 4. Per-panel-variant storage
One JSON per panel variant, never per SKU aggregate. Panel ID read over DSI at boot selects the file; mismatch halts with named-variant error.
```json
{"panel": "variant-A-boe-1080x2280", "resolution": [1080, 2280], "dsi_lanes": 4,
 "mode": {"clock_khz": 158000, "hfp": 20, "hbp": 20, "vfp": 12, "vbp": 8},
 "backlight": {"driver": "pmi8998-wled", "max_nits": 418, "curve": [0, 3, 9, 32, 95, 210, 418], "measured": true, "meter": "T-10 sn42", "date": "2026-05-01"},
 "white": {"cct_k": 6480, "x": 0.312, "y": 0.329, "measured": true},
 "gamma": 2.19, "modifiers": ["LINEAR"], "touch_matrix": [[1,0,0],[0,1,0]], "rotation_quirks": []}
```
Fields `measured`, meter serial, date, operator initials are mandatory. `measured:false` entries block daily-driver promotion for that variant.

## 5. Phosh-to-Android brightness sync check
Host slider → writes `backlight` class and Android `LightsService` (ch.06 §4). Test: sweep Phosh slider 0/25/50/75/100%, assert Android mirror ≤2 levels within 2 s and lux monotonic. HBM/outdoor boost is host-owned; Android `SCREEN_BRIGHTNESS` capped — verify container cannot force HBM (`dumpsys display` shows cap). AOD stays off v1 (power reason logged).

## 6. Failure handling and re-cal triggers
Re-cal on: panel lot change, backlight driver change, DT timing change, `grim` vs `screencap` ΔE-lite mean >6/255, or 12-month age. Archive raw CSVs as `graphics/<sku>/backlight-<variant>-<date>.csv` (columns: host_level, android_level, lux1, lux2, lux3, nits, ambient_lux, temp_c). systemd unit `halide-display-verify.service` (PID1 = systemd) asserts panel.json exists for detected ID before `phosh.service`.

## Verification
- [ ] 7-point lux curve archived per variant with meter serial + date; `measured:true`.
- [ ] White-point/gamma recorded; datasheet-only entries flagged `measured:false`.
- [ ] Phosh slider sweep mirrors to Android ≤2 levels, lux monotonic, HBM cap verified.
- [ ] `grim` vs `screencap` color agreement mean per-channel diff <6/255.
- [ ] Wrong-panel boot halts with named-variant error, never drives wrong timings.
