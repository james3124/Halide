# Camera Tuning Sheet — Per-Sensor Quality & Convergence Log
**Parent: ch.04 §9, appendix-04A §3 · One file per sensor: `camera/<sku>/<sensor>-tuning-<ver>.md` · Mirrors audio-tuning-sheet discipline**

## 1. Preconditions (recorded: sensor rev, lens lot photo, CAMSS driver SHA, libcamera version, adapter version, lux-meter cal, 5-scene rig description — daylight window timed 10:00–14:00 or 5500K box, indoor 300 lux, low-light 10 lux, backlit doorway, macro 10cm ruler)

## 2. Five scenes × 3 shots (all 15, every tuning)

| Scene | Checks | Bar |
|---|---|---|
| Daylight outdoor | AE converge ≤1s, AWB neutral (grey-card ΔCCT ±300K), sharpness center/edge vs stock blind vote | ≥2/3 reviewers rate "indistinguishable-or-better" OR gap named (e.g., "edge softness 15% — no ISP sharpening v1") |
| Indoor 300 lux | Noise vs stock (100% crop triplet attached), skin-tone patch | gap named with numbers (luma-noise σ), not adjectives |
| Low-light 10 lux | Night-mode absent v1 (stated) — measure what exists: exposure time cap (motion-blur honesty: cap 1/15s documented), usable-or-not verdict | verdict + cap committed |
| Backlit doorway | HDR absent/present state (if absent: silhouette accepted + documented; if present: ghosting check on waving hand) | state + artifact log |
| Macro 10cm | Focus lock rate 10/10 attempts + focus-hunt time | ≥9/10 lock, hunt ≤2s median |

AE/AWB convergence traces (`CONTROL_AE_STATE` log) attached per scene (appendix-04A §3) — "feels slow" becomes milliseconds.

## 3. Video (1080p30 60s, ch.04 gate clip + this sheet)

EIS absent v1 (stated — handshake visible in side-by-side vs stock; no stabilization claims), rolling-shutter readout measured once per sensor (ms, panning-ruler method — informs EIS Phase-4 design), audio-video sync offset ms (clap method, ±40ms bar), thermal: 3 consecutive clips without `THERMAL_PRESSURE` step-5 grey-out (ch.06-adjacent thermal contract §4).

## 4. Sign-off (2-person rule, same as audio)

Sensor table (`camera/<sku>/<sensor>.md` capability + quality delta) updated + blind votes + traces → MR needs Camera owner + QA sign. Post-merge: appendix-04A golden refreshed (dump-diff clean with new golden committed same MR — golden and code never drift).

## Verification

- [ ] 15 shots + traces + votes + video clip archived; gaps named with numbers; 2-person sign recorded.
