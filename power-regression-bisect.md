# HALIDE Power Regression Bisect — Nightly Residency to Blame Commit

**Parent: ch.10 power lab + thermal-management + battery-health-aging-policy · Owner: Power + BSP + QA**

## 1. Nightly residency trend alerts

Nightly job flashes tip MANIFEST on REF-A + REF-B lab units (fixed SKU, fixed ambient 23±2°C, same SIM profile, battery 60–80% to exclude aging slope) and runs scenario pack: suspend-8h, screen-off-idle-1h, video-30min, LTE-browse-30min, GNSS-track-30min. Primary metric: residency % in deep states (cpuidle C7+, SoC CX power-collapse) + modem DRX ratio + measured mA per power-results-template.

```bash
halide-power-nightly --suite standard --sku REF-A-4GB --out /srv/power/$(date +%F).csv
# Expected: CSV with residency%, mA per scenario, WA-factor, ambient, battery-cycle-count
# Gotcha: thermal chamber drift or swapped USB meter inflates mA silently
# Fix: pre-run halide-lab-sanity (meter cal tag + ambient probe) — abort if sanity fails, do not file alert
```

Alert rule table (fires only if 3 consecutive nights beyond floor — single-night spikes are noise):

| Scenario | Alert threshold vs 7-day median | Noise floor (ignore below) |
|----------|---------------------------------|----------------------------|
| suspend-8h drain | +15% mA or −5pp deep residency | ±5% meter+thermal noise |
| screen-off-idle | +12% or −4pp | ±4% |
| video / LTE / GNSS active | +10% | ±6% (network variance) |

Alerts file `power/ALERT-<date>.md` with CSV links, ambient log, and auto-linked MANIFEST delta. No alert without sanity-green; honesty over volume.

## 2. Bisect across MANIFEST deltas (kernel vs HAL vs app-layer attribution)

Attribution order is fixed: kernel → HAL/blob → app-layer/bridge. Bisect the MANIFEST range, not individual repos blindly.

1. Freeze inputs: same lab unit, same meter, same ambient window, same NetworkManager single-stack profile (no dual-route experiments mid-bisect), permissions frozen (atomic sync verified — split-brain invalidates power data).
2. Bisect driver: `halide-bisect --good <manifest-A> --bad <manifest-B> --scenario suspend-8h --reps 2`. Each step runs scenario twice; keep-winner needs both reps beyond noise floor.
3. Attribute by layer table:

| Suspect layer | Typical signature | Confirm command |
|---------------|-------------------|-----------------|
| kernel (cpuidle/driver/WA) | deep-residency drop, `cpupower idle-info` C-state missing, dmesg wakeup storm | `cat /sys/kernel/debug/wakeup_sources \| sort -k6 -nr \| head` → Expected: no new active source >5min |
| HAL/blob (camera/sensor/modem FW) | active-scenario drain only, `logcat` HAL wakelock held, modem DRX collapse | `dumpsys power \| grep -i wake_lock` + `mmcli --modem 0 --signal` DRX check |
| app-layer/bridge (Phosh, prop-poll, sync loop) | idle drain with bridge CPU high, `journalctl` poll storm | `systemd-cgtop` + `busctl monitor` poll-rate diff vs good build |

4. Verdict format: blamed commit + layer + signature + both-reps CSV + wakeup-source diff. If bisect straddles kernel+HAL (two culprits), split verdicts — no single-blame fiction.

## 3. WA-factor drift detection

WA-factor (workaround-factor: errata mitigations cost) tracked per SoC in appendix-03B power-domains. New silicon errata or disabled workaround changes idle cost even with correct code.

```bash
halide-wa-audit --sku REF-A-4GB --dump wa-factor.json
# Expected: active WA list matches power-domains baseline; factor within ±3%
# Gotcha: kernel defconfig silently drops ERRATA option → WA off, power looks better but correctness lost
# Fix: diff .config against baseline; re-enable + re-run before claiming win
```

Drift protocol: WA change without Arch+BSP sign is a bisect-invalid event — re-baseline median, annotate ALERT as WA-DRIFT not regression. Never "fix" power by disabling a correctness workaround.

## 4. False-alarm tuning (noise floors per scenario)

Floors reviewed quarterly from 90-day variance. Tuning levers in order: increase reps (2→3) before widening thresholds; split LTE scenarios by RSRP bin (weak-signal nights excluded or binned separately); pin ambient/battery windows tighter before touching thresholds. Every tuning change logged in `power/floors-<quarter>.md` with before/after false-alarm counts. Target: <1 false bisect per month; missed-regression review in annual plan retrospective (kept-vs-rewritten includes power chapter accuracy).

| Tuning action | When | Guardrail |
|---------------|------|-----------|
| reps 2→3 | borderline 10–12% deltas flapping | lab time budget; suspend-8h exempt from >2 reps (time) |
| RSRP binning | LTE variance dominates | carrier-lab-handbook RSRP bins reused, no new bins |
| re-baseline median | WA change / meter recal / new battery | old median archived, never overwritten |

Staged-rollout linkage: power ALERT at S1+ arms OTA auto-halt input (ch.09 §9) — power regressions halt like functional ones. No ship with open S1 power ALERT except documented exception with dogfood data.

## Verification

- [ ] 7-day median + nightly CSVs present; sanity-green required for every ALERT.
- [ ] Each ALERT has 3-night evidence, MANIFEST delta link, layer-attributed verdict with wakeup-source diff.
- [ ] WA-factor audit green; any drift annotated, median re-baselined with sign-off.
- [ ] Floors file current quarter; false-bisect rate <1/month tracked.
- [ ] S1+ power ALERTs wired to rollout halt; exception (if any) has dogfood justification.
