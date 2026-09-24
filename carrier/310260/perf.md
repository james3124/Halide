# perf.md -- 310260 data/voice perf sheet TEMPLATE (ch.07 S6/S11, carrier-profile-example S2)
# Same cell, same hour, 3 runs. Method footnotes MANDATORY (cell id/band, hour, unit label,
# firmware, ambient) -- runs without footnotes rejected. ASCII only. No measurements claimed
# here; TODO until the bench runs.

| Metric | Run1 | Run2 | Run3 | Median | Stock median | Delta | Verdict |
|---|---|---|---|---|---|---|---|
| Attach post-boot (s) | TODO | TODO | TODO | TODO | TODO | TODO | TODO (gate <=90s) |
| iperf down 10min (Mbps) | TODO | TODO | TODO | TODO | TODO | TODO | TODO |
| iperf up (Mbps) | TODO | TODO | TODO | TODO | TODO | TODO | TODO |
| 1h soak drops | TODO | TODO | TODO | TODO | TODO | -- | TODO (gate 0) |
| Hotspot 30min (client MB) | TODO | TODO | TODO | TODO | TODO | TODO | TODO |
| Idle 8h detach count | TODO | TODO | TODO | TODO | TODO | -- | TODO (gate 0) |
| SMS 10/10 (s) med | TODO | TODO | TODO | TODO | TODO | TODO | TODO |

## Footnotes (fill per run)

- cell_id/band: TODO
- hour: TODO
- unit_label: TODO
- modem_fw: TODO (version + short SHA; silent FW swaps inside comparisons = data-integrity fail)
- ambient: TODO (storms affect radio -- note them)
- conducted|r radiated + box ID: TODO
