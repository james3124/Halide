# Carrier Profile Worked Example — `carrier/310260/profile.json` + perf sheet
**Parent: ch.07 §§3,11 · Example values (replace with lab measurements, never ship examples as data)**

## 1. profile.json (schema v1 — CI validates required keys)

```json
{
  "carrier": "Example Mobile (lab SIM, do-not-ship-as-tested)",
  "mcc_mnc": "310260",
  "apn": "fast.example",
  "apn_auth": "none",
  "mvno_type": "gid",
  "ims_apn": "ims",
  "mmsc": "http://mmsc.example/servlets/mms",
  "mms_proxy": "none",
  "voice": "CSFB-verified-2026-05-14",
  "volte": "attempted-failed-QMI-0x4e-see-BUG-ims-042",
  "emergency": "UNTESTED",
  "sim_pin_required": true,
  "data_perf_mbps_med_down": 42.5,
  "data_perf_mbps_med_up": 11.2,
  "notes": "Second SIM slot polarity quirk applies (appendix-03A #4)"
}
```

Rules: `voice`/`volte`/`emergency` accept only controlled vocabulary (`verified-<date>` / `attempted-failed-<reason>-<bug>` / `UNTESTED`); free-text claims rejected by `scripts/carrier-lint.sh`. `UNTESTED` renders bold-red in generated docs (no quiet untested).

## 2. perf.md sheet (same cell, same hour, 3 runs — template)

| Metric | Run1 | Run2 | Run3 | Median | Stock median | Delta | Verdict |
|---|---|---|---|---|---|---|---|
| Attach post-boot (s) | 61 | 74 | 58 | 61 | 44 | +39% | PASS (≤90s gate) |
| iperf down 10min (Mbps) | 41 | 44 | 42 | 42 | 48 | −13% | PASS |
| iperf up (Mbps) | 11 | 12 | 11 | 11 | 13 | −15% | PASS |
| 1h soak drops | 0 | 0 | 0 | 0 | 0 | — | PASS |
| Hotspot 30min (client MB) | 812 | 790 | 805 | 805 | 900 | −11% | PASS |
| Idle 8h detach count | 0 | 0 | 0 | 0 | 0 | — | PASS |
| SMS 10/10 (s) med | 6 | 7 | 6 | 6 | 5 | +20% | PASS |

Method footnotes mandatory: cell id/band, hour, unit label, firmware, ambient — runs without footnotes are rejected (drive-test discipline, ch.07 §6).

## 3. APN provisioning flow (how the JSON gets used)

`mobile-broadband-provider-info` → match MCC/MNC → write NM `gsm` connection → compare with `profile.json` (mismatch → profile wins + `APN_OVERRIDE` journal + Settings shows "carrier settings customized" chip). Manual edit path in Settings writes back a user-overlay (never mutates shipped profile — factory reset restores canonical). MVNO matching order: `spn` → `imsi` → `gid` → fallback (log which matched — wrong-MVNO APN is the classic "registers, no data" cause, ch.07 §8).

## Verification

- [ ] `carrier-lint.sh` green; no `UNTESTED` shipped silently (rendered bold-red).
- [ ] Perf sheet with footnotes archived per blessed carrier/SKU.
