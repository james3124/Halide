# STABLE-TRIAGE-6.6.30.md — LTS bump triage template (ch.03 §26 Week-1 train).
# One file per bump: kernel/STABLE-TRIAGE-<ver>.md with per-commit relevance.
# Skip rule: zero relevant-subsystem commits may fast-track Week1->4 with Arch + QA
# sign, but the triage file is still required ("nothing relevant" is a claim with evidence).

Bump: v6.6.OLD -> v6.6.30 (date: TODO)
Range: git log v6.6.OLD..v6.6.30 --oneline (count: TODO)

## Flagged for HW attention
| Commit | Subsystem (display/mm/net/arm64/qcom/rtc/alarmtimer/iommu) | Relevance | Gate probe |
|---|---|---|---|
| TODO-sha | e.g. drivers/iommu/arm-smmu | §39 fwspec audit re-run? | smmu-audit.py PASS |
| TODO-sha | e.g. kernel/time/alarmtimer.c | §36 alarm path renamed? | halide-time-check green |

## Informational (no HW impact claimed — evidence above, not prose)
- TODO-sha one-line summary

## Gates for this bump
- [ ] abi-gate.py line recorded (UNCHANGED / ADDITIVE-ONLY / BREAK + justification MR)
- [ ] CI full (§25) + 50-cycle suspend (§17) + modem ladder (§14) + composer smoke (ch.06 §10 subset)
- [ ] KMI string vs abi/6.6/vermagic.pin compared
- [ ] Rollback-index note if AVB-relevant (§6)
