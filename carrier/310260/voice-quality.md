# voice-quality.md -- 310260 voice-quality aggregates TEMPLATE (ch.07 S22)
# Aggregated weekly from ~/.local/share/halide/calls/<date>.csv (redacted source).
# ASCII only. No values claimed until bench runs.

carrier: 310260
week: TODO-YYYY-Www
modem_fw: TODO (version + short SHA)

## Aggregates (trailing window; per-scenario split quiet/street/car/speaker/headset)

- calls_total: TODO
- setup_success_pct: TODO (gate >=98% over 50 calls)
- drop_pct: TODO (gate <=2%)
- median_setup_ms: TODO (gate <=8s CS)
- one_way_audio_count: TODO (gate 0/50)
- underrun_rate: TODO
- user_flagged: TODO (report-bad-call tags; ground truth for P1 triage)

## Per-scenario split

| Scenario | Calls | Setup% | Drop% | Median setup | Underruns | Verdict |
|---|---|---|---|---|---|---|
| quiet | TODO | TODO | TODO | TODO | TODO | TODO |
| street | TODO | TODO | TODO | TODO | TODO | TODO |
| car | TODO | TODO | TODO | TODO | TODO | TODO |
| speaker | TODO | TODO | TODO | TODO | TODO | TODO |
| headset | TODO | TODO | TODO | TODO | TODO | TODO |

miss_path: gains (call-gains.conf) -> antenna/RF check -> modem-fw note -> carrier escalation
