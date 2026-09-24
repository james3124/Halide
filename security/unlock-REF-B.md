# unlock-REF-B.md -- unlock-latency evidence, REF-B (ch.08 S9 + S32)
# Owner: Security + QA * 20-run median, footnote set per ch.10 S12.
# Values TODO until measured -- TODO is honest; invented numbers are forbidden.

| Run | p50 screen-on to keyring-available (ms) | p95 (ms) | Footnotes |
|---|---|---|---|
| TODO-1..20 | TODO | TODO | TODO (unit, firmware, ambient C, battery %) |

SLO: p50 <= 1600 ms, p95 <= 2500 ms (must BEAT REF-A; regression = P1 perf bug).
KDF: Argon2id m=1536MB / t=4 / p=4 (raised only with evidence in the MR).
Result: TODO (PASS / FAIL with dated plan).
