# Audio Tuning Sheet — Per-SKU Call Gains & Measurements
**Parent: ch.04 §8, bridges/audio · One file per SKU: `audio/<sku>/tuning-<ver>.md` · No gain ships without this sheet**

## 1. Preconditions (all recorded, all current)

`tinymix.txt` SHA matches golden (appendix-04A §4) · `policy.json` version · modem firmware · speaker/mic hardware rev (photo of flex + date code — silent HW revs change acoustics) · ambient noise floor dBA (meter model + cal date) · test numbers (echo-service + far-end recording rig décrits: far-end is a wired reference phone in a quiet box, not someone's pocket).

## 2. Five scripted calls (all 5, every tuning — no partial tunes)

| # | Scene | Path | Gains touched | Pass criteria |
|---|---|---|---|---|
| 1 | Quiet room 30dBA | earpiece+mic | rx/tx baseline | far-end MOS-subjective ≥4, no hiss (noise floor ≤−60dBFS) |
| 2 | Street 65dBA (played noise, calibrated) | earpiece+mic | tx NR aggressiveness, rx comp | far-end intelligible (phonetically-balanced sentence list 18/20), no pumping artifacts |
| 3 | Car 70dBA + BT HFP (reference headset model) | SCO | ec tail, sco gain | no howling on double-talk 10s, far-end echo ≤−40dB |
| 4 | Speakerphone desk | speaker+2mics | speaker cap (ch.08-adjacent safety cap value + source), tx beam | no feedback at max volume, far-end echo ≤−40dB |
| 5 | Headset wired (3.5mm/USB-C per SKU) | headset path | jack/USB gain parity ±2dB vs earpiece loudness | L/R balance, mic level match |

Each row: before/after `tinymix` diff hunk + far-end recording hash + 3-reviewer blind vote (stock vs tuned vs previous-tune — honesty rule from ch.04 §9 camera section applies to ears too).

## 3. Safety caps (binding, from datasheets — not taste)

Speaker max gain from driver excursion/Xmax + thermal rating (value + datasheet page cited in `policy.json` comment); earpiece long-call limit (30-min thermal soak, coil temp estimate via current draw — no melted earpieces, ever). Boot jingle / haptic-coupled audio capped −6dB below speaker max (transients lie on meters; cap is conservative by design).

## 4. Regression & sign-off

`call-gains.conf` diff + this sheet + far-end recordings → MR needs Audio owner + QA sign (2-person rule — single-person gain pushes corrupted two releases in other projects; the rule is written in blood). Post-merge: `audio/<sku>/measurements.md` plots refreshed (sine THD+N + pink-noise response, ch.04 §8 loopback) + 5-call log linked from release notes (users with sensitive ears deserve the data).

## Verification

- [ ] All 5 calls logged with diffs + votes; safety caps cited; 2-person sign recorded.
