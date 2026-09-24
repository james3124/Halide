# ADRs - architecture decision records (ch.11 S14: the why behind the what).
# Format per entry (program/adr/<NNN>-<slug>.md): Context -> Options (>=2 with
# tradeoffs) -> Decision -> Consequences (what gets harder) -> Revisit-when
# (date or trigger; decisions without revisit conditions calcify).
# New architecturally-significant choice without ADR = review fail.

## Index (newest first)
| ID | Title | Status |
|---|---|---|
| ADR-001 | systemd-as-PID1 over Android-init (ch.00 + ch.05 consequences) | TODO-accept |
| ADR-002 | single-stack NM networking (Android second-supplicant forbidden) | TODO-accept |
| ADR-003 | host-owns-modem (dual-master ban, ch.07 S1) | TODO-accept |
| ADR-004 | no-GMS v1 (trust posture, ch.01 S12) | TODO-accept |
| ADR-005 | erofs read-only partitions (verity + repro, ch.09 S8) | TODO-accept |
| ADR-006 | permission atomicity (no split-brain, bridges/permission S2) | TODO-accept |

Seeded entries carry full Context/Options/Decision/Consequences/Revisit-when
bodies; placeholder rows above become full files before v1 ship.
