# Acoustic Lab Spec — Quiet Box, References, and Calibration
**Parent: audio-tuning-sheet.md / 04-aosp-base-hals.md §8 (audio bridge)**

## 1. Lab scope and quiet-box build
This lab produces the far-end evidence behind every `audio/<sku>/tuning-<ver>.md` 5-call tune. No gain ships without a sheet, and no sheet is valid without lab provenance recorded in §1 of that sheet. Quiet box: sealed MDF enclosure 60×60×60 cm interior, 25 mm acoustic foam (wedge, NRC ≥0.85) on 5 sides, device cradle on sorbothane feet decoupled from table, cable passthrough with foam gland (no hard conduit transmitting vibration). Ambient inside box ≤28 dBA with lab HVAC on, verified per session with meter at cradle position, lid closed, 30 s Leq. Lab room itself ≤35 dBA; no tuning during construction/cleaning hours. Procedure per session: (1) close empty box, log 30 s Leq + meter model + cal date; (2) mount DUT in cradle, route cables via gland, close lid; (3) re-log 30 s Leq (must stay ≤30 dBA or abort); (4) run 5-call script in order (quiet/street/car/speakerphone/headset). Host-owns-modem holds in lab: calls routed via real modem RF (conducted or callbox, never VoIP substitution) unless sheet explicitly declares substitution with justification.

## 2. Reference transducers, meters, and calibration dates
All acoustics-affecting hardware is versioned; silent HW revs invalidate prior tunes.

| Asset | Reference model (or equivalent with approval) | Role | Cal / record requirement |
|---|---|---|---|
| Sound level meter | Class-2 SLM (e.g. NTi XL2 or B&K 2250-L) | dBA floor + playback level | Annual cal; sticker + cert PDF in `audio/lab/cal/`; cal date in every tuning sheet §1 |
| Measurement mic | 1/2" free-field + calibrator 94 dB/1 kHz | Box + room verification | Pre-session 94 dB check ±0.5 dB; annual lab cal |
| Playback speaker | Single powered monitor (flat ±3 dB 100 Hz–10 kHz at 1 m) | Street/car/home noise | Monthly pink-noise sanity (response plot archived); position fixed 1 m from cradle, marked on floor |
| Far-end reference phone | Wired handset, model pinned per SKU lab config | Far-end judge | No speakerphone, no BT at far end; model + FW in sheet; replacement requires 1-call re-baseline |
| BT reference headset | One pinned HFP headset per SKU (car test) | SCO path | Model + FW pinned; headset battery ≥80% before car call |
| Wired headset | 3.5 mm + USB-C refs per SKU connector | Headset parity | L/R balance checked monthly on loopback |
| Cables/adapters | Pinned SKUs, no substitutions | Repeatability | Photo of flex + date code in sheet when speaker/mic rev changes |

Expired cal blocks tuning: `audio-lab-check` script refuses to stamp `measurements.md` if any cert is past due. Loaner gear requires Audio-owner exception with re-baseline call #1.

## 3. Noise-playback calibration (dBA levels mapping)
Played noise replaces street/car/home; levels are calibrated at the DUT mic position, lid open for setup then closed for test, speaker position fixed. Files: 16-bit WAV pink-shaped speech-babble (street/home) and road+engine mix (car), 60 s loop, hashes pinned in `audio/lab/noise/README.md`.

| Scene (tuning-sheet call #) | Target at DUT position | Source file | Setup procedure |
|---|---|---|---|
| Quiet room (#1) | ≤30 dBA Leq | None (box closed, playback off) | Verify per §1; abort if HVAC spike |
| Home / desk (#4 adj) | 45 dBA ±2 | `home-babble-45.wav` | Play, SLM at cradle, adjust amp to 45, log gain knob photo |
| Street (#2) | 65 dBA ±2 | `street-babble-65.wav` | Same; 30 s Leq; lock amp; do not touch mid-call |
| Car + BT HFP (#3) | 70 dBA ±2 | `car-road-70.wav` | Same at 70; headset worn on dummy head or fixture, mic port unobstructed |

Recalibrate whenever speaker moves, room changes, or monthly — whichever first. Log per tuning: file hash + SLM reading + meter cal date + amp setting. Never set level by ear or phone app; only the Class-2 SLM counts. Transients (door slams) invalidate the take — redo the call.

## 4. Far-end rig
Far-end is a wired reference phone in the quiet box (second box or partitioned session — never the reviewer's pocket, never a laptop speaker). Path: DUT → modem → carrier/callbox → far-end wired handset → line-out to USB capture (48 kHz/16-bit) for hash + blind vote. Capture chain gain is fixed and labeled; changing it mid-tune invalidates all prior takes. Procedure: (1) place far-end call to echo-service to verify capture noise floor ≤−60 dBFS; (2) run phonetically-balanced sentence list (18/20 intelligible = pass for street call); (3) save raw WAV + SHA256 in take folder; (4) normalize copies only for blind vote (originals retained). Far-end operator scores MOS-subjective independently before seeing gains. Redacted logs: capture filenames contain SKU + date + call#, never IMSI/IMEI/phone numbers; support-log-script redaction verified on any attached `dmesg`/modem excerpt.

## 5. Double-talk fixture
Car (#3) and speakerphone (#4) passes require controlled double-talk: far-end plays a −20 dBFS 1 kHz-gated speech burst (5 s on / 5 s off, 10 s total) while near-end operator reads the sentence list. Pass criteria: no howling, far-end echo ≤−40 dB, no pumping artifacts (per tuning-sheet §2). Fixture: far-end line-in fed from pinned WAV (`doubletalk-burst.wav`, hash pinned), level verified on capture meter before each session. Procedure: start near-end read → trigger burst at t=2 s → record 10 s → measure echo during far-end-only gaps. Failure modes map to gains: howling → reduce SCO/speaker cap + extend EC tail; pumping → relax TX NR aggressiveness one step and re-run street call too (NR changes couple). Three-reviewer blind vote (stock vs tuned vs previous-tune) required per take; honesty rule applies to ears — ties go to prior tune, never to the new one without evidence.

## 6. Measurement file naming and retention
One folder per tune: `audio/<sku>/<date>-<ver>/` containing `tinymix.txt`, `policy.json`, `tuning.md` (the sheet), `takes/call{1..5}_{before,after}.wav` + `.sha256`, `slm-log.txt`, `vote.csv`. Naming: `halide_<sku>_<yyyymmdd>_call<N>_<before|after>_<nr-setting>.wav` (e.g. `halide_sdm845_20260601_call2_after_nr-med.wav`). Retention: raw takes 2 releases or 12 months (longer wins); winning-tune takes retained with release artifacts; losing takes retained but marked `superseded`. `measurements.md` plots (sine THD+N + pink-noise response) refreshed post-merge per tuning-sheet §4 and link the 5-call log from release notes. No fake claims: plots show measured curves with box/mic/cal annotation — never smoothed marketing curves; failed takes stay in folder with `FAIL` prefix and reason.

## Verification
- [ ] Box ≤28 dBA empty / ≤30 dBA loaded per session; meter model + cal date logged; expired cal blocks stamp.
- [ ] Playback levels verified at DUT position (45/65/70 dBA ±2) with pinned WAV hashes; amp locked mid-call.
- [ ] Far-end is wired reference in quiet box with fixed capture chain; floor ≤−60 dBFS; filenames redacted.
- [ ] Double-talk burst procedure run for calls #3/#4; echo ≤−40 dB; blind 3-vote recorded, ties keep prior tune.
- [ ] Folder naming exact; retention 2 releases/12 mo; plots refreshed with cal annotation; FAIL takes retained.
