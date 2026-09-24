# unlock-REF-A.md -- unlock-latency evidence, REF-A SDM845 (ch.08 S9 + S32)
# Owner: Security + QA * 20-run median, footnote set per ch.10 S12
# (unit label + firmware + ambient). Values TODO until measured on silicon --
# TODO is honest; invented numbers are fake audit results and are forbidden.

| Run | p50 screen-on to keyring-available (ms) | p95 (ms) | Footnotes |
|---|---|---|---|
| TODO-1..20 | TODO | TODO | TODO (unit, firmware, ambient C, battery %) |

SLO: p50 <= 2000 ms, p95 <= 3000 ms on REF-A slow cores (luks2-params.conf).
KDF: Argon2id m=1024MB / t=4 / p=2. Method: cryptsetup benchmark + 20 cold
unlocks, median; re-measure per KDF ceremony delta (S32 (a)).
Result: TODO (PASS / FAIL with dated plan -- red blocks release per S32 drill rule).
